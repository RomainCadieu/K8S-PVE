#
#   Generation of VYOS Template for Qemu / Proxmox
#


# Create a Debian Temporary VM to create VyOS cloud-init image and send it to the hypervisor (Proxmox)

resource "proxmox_virtual_environment_vm" "VyOS_CI" {
    # This VM uses template of Debian from this module. That's why it depend on it. :)
    depends_on = [null_resource.templatization]
    count               =   1
    name                =   "VyOSCI"
    description         =   "VyOS_CI, temporary VM to be deleted managed by Terraform"
    tags                =   ["terraform", "Debian12", "Ansible", "primary"]
    node_name           =   var.Proxmox.Node
    vm_id               =   format("%2s%02s",var.Template.Id_prefix, 12)
    on_boot           = false
    started           = true

    clone {
        datastore_id    =   var.Proxmox.Datastore
        node_name       =   var.Proxmox.Node
        retries         =   3 
        vm_id           =   proxmox_virtual_environment_vm.template_debian_vm[0].vm_id
        full            =   true
    }
    
    disk {
        datastore_id    = var.Proxmox.Datastore
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
                address =   "${var.Template.Ip_prefix}${var.Template.Ip_suffix + 1}${var.Template.Mask}"
                gateway =   var.WAN_GW
            }
        }

        user_account {
            keys          = [trimspace(var.Template.SSH_key)]
            username    = "ubuntu"
            password = random_password.template_debian_password.result
        }
        datastore_id    = var.Proxmox.Datastore
    }
    connection {
        type     = "ssh"
        user     = "ubuntu"
        password = random_password.template_debian_password.result
        private_key = "${file(var.Template.SSH_local_file)}"
        host     = "${var.Template.Ip_prefix == "dhcp" ? "dhcp" : "${var.Template.Ip_prefix}${var.Template.Ip_suffix + 1}"}"
    }
    provisioner "remote-exec" {
        inline = [
          "sudo apt install -y git ansible wget sshpass",
          "cd /tmp && wget https://github.com/vyos/vyos-rolling-nightly-builds/releases/download/${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-amd64.iso",
          "git clone https://github.com/vyos/vyos-vm-images.git && cd vyos-vm-images",
          "sed -i '/^ - download-iso/d' qemu.yml",
          "sudo ansible-playbook qemu.yml -e disk_size=10 -e iso_local=/tmp/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-amd64.iso -e cloud_init=true -e cloud_init_ds=NoCloud -e guest_agent=qemu -e enable_ssh=true",
          "sshpass -p ${var.Proxmox.SSH_password} scp -o StrictHostKeyChecking=accept-new /tmp/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-cloud-init-10G-qemu.qcow2 ${var.Proxmox.SSH_username}@${var.Proxmox.Ip}:"
        ]
    }
}

# Destroy previous VM and create a VM template from .qcow2 file
#!# It would be great that this template be managed by terraform, it might be an improvement in the future. Currently I don't implement it because of performance issues

resource "null_resource" "VyOS_CI2" {
  depends_on = [proxmox_virtual_environment_vm.VyOS_CI]
  connection {
    type     = "ssh"
    user     = var.Proxmox.SSH_username
    password = var.Proxmox.SSH_password
    host     = var.Proxmox.Ip
  }
  provisioner "remote-exec" {
    inline = [
      "mv vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-cloud-init-10G-qemu.qcow2 /tmp",
      "qm stop ${proxmox_virtual_environment_vm.VyOS_CI[0].vm_id} && qm destroy ${proxmox_virtual_environment_vm.VyOS_CI[0].vm_id}",
      "qm create ${format("%2s%02s",var.Template.Id_prefix, 02)} --name vyos-${ var.VyOS_version.Major } --numa 0 --ostype l26 --cpu cputype=host --cores 2 --sockets 1 --memory 2048 --net0 virtio,bridge=vmbr0",
      "qm importdisk ${format("%2s%02s",var.Template.Id_prefix, 02)} /tmp/vyos-${ var.VyOS_version.Major }-${ var.VyOS_version.Branch }-${ var.VyOS_version.Minor }-cloud-init-10G-qemu.qcow2 ${var.Proxmox.Datastore}",
      "qm set ${format("%2s%02s",var.Template.Id_prefix, 02)} --scsihw virtio-scsi-pci --scsi0 ${var.Proxmox.Datastore}:vm-${format("%2s%02s",var.Template.Id_prefix, 02)}-disk-0",
      "qm set ${format("%2s%02s",var.Template.Id_prefix, 02)} --boot c --bootdisk scsi0",
      "qm set ${format("%2s%02s",var.Template.Id_prefix, 02)} --ide2 ${var.Proxmox.Datastore}:cloudinit",
      "qm template ${format("%2s%02s",var.Template.Id_prefix, 02)}",
    ]
  }
}
locals {
  depends_on = [null_resource.VyOS_CI2]
  VyOS_template_ID = "${format("%2s%02s",var.Template.Id_prefix, 02)}"
}