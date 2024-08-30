    ###################################################
    #               Deploy Ansible VM                 #
    ###################################################

#_________________________________________________________#
#      Deploy Ansible VM with minimal configuration       #
#‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾#

resource "proxmox_virtual_environment_vm" "ansible" {
  depends_on = [ null_resource.wait_before_VyOS ]
  count             =   1
  name              =   "Ansible"
  description       =   "Ansible, managed by Terraform"
  tags              =   ["Terraform", "Debian12", "Ansible"]
  node_name         =   var.Proxmox.Node
  vm_id             =   var.Ansible.Id
  on_boot           = false
  started           = true

  clone {
    datastore_id    =   var.Proxmox.Datastore
    node_name       =   var.Proxmox.Node
    retries         =   3 
    vm_id           =   var.Template_Id
    full            =   true
  }
  cpu {   
    cores           =   1
  }
  disk {
    datastore_id    = var.Proxmox.Datastore
    interface       = "scsi0"
    size            = 20
    file_format     = "raw"
  }
  agent {
    enabled         =   true
  }
  network_device {
    bridge          = "vmbr0"
    vlan_id         = "100"
  }
  network_device {
    bridge          = "vmbr0"
  }
  initialization {
    ip_config {
      ipv4 {
        address     =   "${var.Ansible.Ip == "dhcp" ? "dhcp" : "${var.Ansible.Ip}${var.Ansible.Mask}"}"
        gateway     =   var.LAN_GW
      }
    }
    ip_config {
      ipv4 {
        address     =   "${var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix}${var.VyOS.LAN_Mask}"
      }
    }
    user_account {
      keys          = [trimspace(var.Template.SSH_key)]
      password      = random_password.ansible_password.result
      username      = random_string.ansible_username.result
    }
    datastore_id    = var.Proxmox.Datastore
  }
  connection {
    type            = "ssh"
    user            = random_string.ansible_username.result
    password        = random_password.ansible_password.result
    private_key     = "${file(var.Template.SSH_local_file)}"
    host            = "${var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo deluser --remove-home ubuntu",
      "sudo apt update && sudo apt upgrade -y",
      "sudo apt install wget gpg -y",
      "wget -O- 'https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367' | sudo gpg --dearmour -o /usr/share/keyrings/ansible-archive-keyring.gpg",
      "echo 'deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu jammy main' | sudo tee /etc/apt/sources.list.d/ansible.list",
      "sudo apt update && sudo apt install ansible python3-full python3-pip -y",
      "sudo mkdir -p /etc/ansible /home/$USER/.ssh/",
      "ansible-galaxy collection install kubernetes.core community.kubernetes cloud.common",
      "sudo mv /usr/lib/python3.11/EXTERNALLY-MANAGED /usr/lib/python3.11/EXTERNALLY-MANAGED.old",
      "pip install kubernetes",
      "sudo chown $USER /etc/ansible",
    ]
  }
  provisioner "file" {
    content         = tls_private_key.ansible_vm_key.private_key_openssh
    destination     = ".ssh/id_rsa"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/$USER/.ssh/id_rsa",
    ]
  }
}

#___________________________________________________________#
# Generate random values for username, password and SSH key #
#‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾#

resource "random_string" "ansible_username" {
  length           = 16
  special          = false
}
resource "random_password" "ansible_password" {
  length            = 16
  override_special  = "_%@"
  special           = true
}

resource "tls_private_key" "ansible_vm_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

output "ansible_vm_password" {
  value     = random_password.ansible_password.result
  sensitive = true
}
output "ansible_vm_public_key" {
  value = tls_private_key.ansible_vm_key.public_key_openssh
}
