#
#   Generation of Debian Template for Qemu / Proxmox
#

# Create a Debian VM with minimal specs to be replicated easily. 

resource "proxmox_virtual_environment_vm" "template_debian_vm" {
  count             = 1
  name              = "template-deb12"
  description       = "Do not touch, Template VM managed by K8Srraform"
  node_name         = var.Proxmox.Node
  vm_id             = format("%2s%02s",var.Template.Id_prefix, 01)
  on_boot           = false
  started           = false

  agent {
    enabled         = false
  }

  cpu {   
    sockets         = 1
    cores           = 2
    type            = "host"
  }
  memory {
    dedicated       = 2048
  }
  initialization {
    ip_config {
      ipv4 {
        address     = "${var.Template.Ip_prefix}${var.Template.Ip_suffix}${var.Template.Mask}"
        gateway     = var.WAN_GW
      }
    }

    user_account {
      keys          = [trimspace(var.Template.SSH_key)]
      password      = random_password.template_debian_password.result
      username      = "ubuntu"
    }
    datastore_id    = var.Proxmox.Datastore
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
    user     = var.Proxmox.SSH_username
    password = var.Proxmox.SSH_password
    host     = var.Proxmox.Ip
  }
  provisioner "remote-exec" {
    inline = [
      "[ ! -f /root/K8Srraform/debian-12-generic-amd64.qcow2 ] && { mkdir -p /root/K8Srraform; cd /root/K8Srraform; wget https://cloud.debian.org/images/cloud/${ var.Debian_version.MajorFQDN }/${ var.Debian_version.MinorID }/debian-${ var.Debian_version.MajorID }-generic-amd64.qcow2; }",
      "cd /root/K8Srraform/",
      "qm importdisk ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id} debian-12-generic-amd64.qcow2 ${var.Proxmox.Datastore}",
      "grep -v '^unused0' /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}.conf > /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf && echo 'scsi0: ${var.Proxmox.Datastore}:vm-${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}-disk-0,size=2G' >> /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf",
      "grep -v '^boot' /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf > /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/temp.conf && echo 'boot: order=scsi0' >> /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/temp.conf",
      "rm /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/template.conf && mv /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/temp.conf /etc/pve/nodes/${proxmox_virtual_environment_vm.template_debian_vm[0].node_name}/qemu-server/${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}.conf",
      "qm resize ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id} scsi0 +18G",
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
    private_key = "${file(var.Template.SSH_local_file)}"
    #private_key = tls_private_key.template_debian_key.private_key_pem
    host     = "${var.Template.Ip_prefix}${var.Template.Ip_suffix}"
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
    user     = var.Proxmox.SSH_username
    password = var.Proxmox.SSH_password
    host     = var.Proxmox.Ip
  }
  provisioner "remote-exec" {
    inline = [
      "qm template ${proxmox_virtual_environment_vm.template_debian_vm[0].vm_id}",
      "sleep 10s" #
    ]
  }
}
