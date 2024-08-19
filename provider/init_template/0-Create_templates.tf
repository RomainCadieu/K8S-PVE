terraform {
  required_providers {
    proxmox         = {
      source        = "bpg/proxmox"
      version       = "0.61.1"
    }
    ansible         = {
      source        = "ansible/ansible"
      version       = "1.3.0"
    }
  }
}

provider "proxmox" {
  #Read the doc of bpg/proxmox https://registry.terraform.io/providers/bpg/proxmox/latest/docs
  endpoint          = var.PROXMOX_VE_ENDPOINT
  username          = var.PROXMOX_VE_USERNAME
  password          = var.PROXMOX_VE_PASSWORD
  insecure          = true

  ssh {
    agent           = false
  }
}

resource "proxmox_virtual_environment_vm" "template_debian_vm" {
  count             = 1
  name              = "template-deb12"
  description       = "Do not touch, Template VM managed by K8Srraform"
  node_name         = var.PROXMOX_VE_DEFAULT_NODE
  vm_id             = format("%2s%02s",var.TEMPLATE_ID_PREFIX, 01)
  on_boot           = false
  started           = false

  agent {
    enabled         = false
  }

  cpu {   
    sockets         = 1
    cores           = 2
    type            = "x86-64-v3"
  }
  memory {
    dedicated       = 2048
  }
  initialization {
    ip_config {
      ipv4 {
        address     = "${var.TEMPLATE_IP}${var.TEMPLATE_MASK}"
        gateway     = var.TEMPLATE_GW
      }
    }

    user_account {
      keys          = [trimspace(var.TEMPLATE_SSH)]
      #keys         = [trimspace(var.TEMPLATE_SSH), trimspace(tls_private_key.template_debian_key.public_key_openssh)]
      password      = random_password.template_debian_password.result
      username      = "ubuntu"
    }
    datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE 
  }

  network_device {
    bridge          = "vmbr0"
  }

  operating_system {
    type            = "l26"
  }

}

resource "random_password" "template_debian_password" {
  length            = 16
  override_special  = "_%@"
  special           = true
}

resource "tls_private_key" "template_debian_key" {
  algorithm         = "RSA"
  rsa_bits          = 2048
}

resource "time_sleep" "wait_pre_provide_ci_vm" {
  depends_on = [proxmox_virtual_environment_vm.template_debian_vm[0]]

  create_duration = "10s"
}

resource "null_resource" "pre_provide_ci_vm" {
  depends_on = [proxmox_virtual_environment_vm.template_debian_vm[0], time_sleep.wait_pre_provide_ci_vm]
  connection {
    type     = "ssh"
    user     = var.PROXMOX_VE_SSH_USERNAME
    password = var.PROXMOX_VE_SSH_PASSWORD
    host     = var.PROXMOX_VE_IP
  }
  provisioner "remote-exec" {
    inline = [
      "[ ! -f /root/K8Srraform/debian-12-generic-amd64.qcow2 ] && { mkdir -p /root/K8Srraform; cd /root/K8Srraform; wget https://cloud.debian.org/images/cloud/${ var.Debian_version.MajorFQDN }/${ var.Debian_version.MinorID }/debian-${ var.Debian_version.MajorID }-generic-amd64.qcow2; }",
      "cd /root/K8Srraform/",
      "qm importdisk ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id} debian-12-generic-amd64.qcow2 ${var.PROXMOX_VE_DEFAULT_DATASTORE}",
      "grep -v '^unused0' /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}.conf > /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf && echo 'scsi0: ${var.PROXMOX_VE_DEFAULT_DATASTORE}:vm-${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}-disk-0,size=2G' >> /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf",
      "grep -v '^boot' /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf > /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/temp.conf && echo 'boot: order=scsi0' >> /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/temp.conf",
      "rm /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf && mv /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/temp.conf /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}.conf",
      "qm resize ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id} scsi0 +28G",
      "qm start ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}",
      "sleep 10s"
    ]
  }
}

#Connexion to the VM created to apply qemu agent and refresh the cloud-init for the deployment

resource "null_resource" "pre_config_ci_vm" {
  depends_on = [null_resource.pre_provide_ci_vm]
  connection {
    type     = "ssh"
    user     = "ubuntu"
    password = random_password.template_debian_password.result
    private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
    #private_key = tls_private_key.template_debian_key.private_key_pem
    host     = var.TEMPLATE_IP
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 10s", #Waiting VM startup
      "sudo su -c 'apt install qemu-guest-agent -y'", #Install qemu guest agent
      "sudo su -c 'systemctl enable qemu-guest-agent'", #Enable it
      "sudo su -c 'cat /dev/null > /etc/machine-id && sudo cat /dev/null > /var/lib/dbus/machine-id'", #Prepare the model
      "sudo su -c 'cloud-init clean'",
      "sudo su -c 'shutdown -h now'", 
    ]
  }
}


resource "time_sleep" "wait_templatization" {
  depends_on = [null_resource.pre_config_ci_vm]

  create_duration = "20s"
}

#Connexion to Proxmox Hypervisor to transform the VM to a template

resource "null_resource" "templatization" {
  depends_on = [time_sleep.wait_templatization]
  connection {
    type     = "ssh"
    user     = var.PROXMOX_VE_SSH_USERNAME
    password = var.PROXMOX_VE_SSH_PASSWORD
    host     = var.PROXMOX_VE_IP
  }
  provisioner "remote-exec" {
    inline = [
      "qm template ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}",
      "sleep 10s" #
    ]
  }
}

# Temporary VM to create VyOS cloud-init image

resource "proxmox_virtual_environment_vm" "VyOS_CI" {
    depends_on = [null_resource.templatization]
    count               =   1
    name                =   "VyOSCI"
    description         =   "VyOS_CI, temporary VM to be deleted managed by Terraform"
    tags                =   ["terraform", "Debian12", "Ansible", "primary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   format("%2s%02s",var.TEMPLATE_ID_PREFIX, 12)
    on_boot           = false
    started           = true

    clone {
        datastore_id    =   var.PROXMOX_VE_DEFAULT_DATASTORE
        node_name       =   var.PROXMOX_VE_DEFAULT_NODE
        retries         =   3 
        vm_id           =   proxmox_virtual_environment_vm.template_debian_vm[0].vm_id
        full            =   true
    }
    
    disk {
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
        interface       = "scsi0"
        size            = 30
        file_format     = "raw"
    }
    agent {
        enabled         =   true
    }

    initialization {
        ip_config {
            ipv4 {
                address =   "${var.ANSIBLE_IP == "dhcp" ? "dhcp" : "${var.ANSIBLE_IP}${var.ANSIBLE_MASK}"}"
                gateway =   var.ANSIBLE_GW
            }
        }

        user_account {
            keys          = [trimspace(var.TEMPLATE_SSH)]
            username     = "ubuntu"
            password = random_password.template_debian_password.result
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
        type     = "ssh"
        user     = "ubuntu"
        password = random_password.template_debian_password.result
        private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
        host     = "${var.ANSIBLE_IP == "dhcp" ? "dhcp" : "${var.ANSIBLE_IP}"}"
    }
    provisioner "remote-exec" {
        inline = [
          "sudo apt install -y git ansible wget sshpass",
          "cd /tmp && wget https://github.com/vyos/vyos-rolling-nightly-builds/releases/download/${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-amd64.iso",
          "git clone https://github.com/vyos/vyos-vm-images.git && cd vyos-vm-images",
          "sed -i '/^ - download-iso/d' qemu.yml",
          "sudo ansible-playbook qemu.yml -e disk_size=10 -e iso_local=/tmp/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-amd64.iso -e cloud_init=true -e cloud_init_ds=NoCloud -e guest_agent=qemu -e enable_ssh=true",
          "sshpass -p ${var.PROXMOX_VE_SSH_PASSWORD} scp -o StrictHostKeyChecking=accept-new vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-cloud-init-10G-qemu.qcow2 ${var.PROXMOX_VE_SSH_USERNAME}@${var.PROXMOX_VE_IP}:"
        ]
    }
}
resource "null_resource" "VyOS_CI2" {
  depends_on = [proxmox_virtual_environment_vm.VyOS_CI]
  connection {
    type     = "ssh"
    user     = var.PROXMOX_VE_SSH_USERNAME
    password = var.PROXMOX_VE_SSH_PASSWORD
    host     = var.PROXMOX_VE_IP
  }
  provisioner "remote-exec" {
    inline = [
      "mv vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-cloud-init-10G-qemu.qcow2 /tmp",
      "qm stop ${proxmox_virtual_environment_vm.VyOS_CI[0].vm_id} && qm destroy ${proxmox_virtual_environment_vm.VyOS_CI[0].vm_id}",
      "qm create ${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)} --name vyos-${ var.VyOS_version.Major }-cloud-init --numa 0 --ostype l26 --cpu cputype=host --cores 2 --sockets 1 --memory 2048 --net0 virtio,bridge=vmbr0",
      "qm importdisk ${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)} /tmp/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-cloud-init-10G-qemu.qcow2 ${var.PROXMOX_VE_DEFAULT_DATASTORE}",
      "qm set ${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)} --scsihw virtio-scsi-pci --scsi0 ${var.PROXMOX_VE_DEFAULT_DATASTORE}:vm-${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)}-disk-0",
      "qm set ${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)} --boot c --bootdisk scsi0",
      "qm set ${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)} --ide2 ${var.PROXMOX_VE_DEFAULT_DATASTORE}:cloudinit",
      "qm template ${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)}",
    ]
  }
}