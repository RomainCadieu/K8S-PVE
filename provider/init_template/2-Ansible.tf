
##################################################
# Ansible VM 
##################################################
resource "proxmox_virtual_environment_vm" "ansible" {
    depends_on = [null_resource.templatization]
    count               =   1
    name                =   "Ansible"
    description         =   "Ansible, managed by Terraform"
    tags                =   ["terraform", "Debian12", "Ansible", "primary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   var.ANSIBLE_ID
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
            password      = random_password.ansible_password.result
            username      = random_string.ansible_username.result
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
        type     = "ssh"
        user     = random_string.ansible_username.result
        password = random_password.ansible_password.result
        private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
        host     = "${var.ANSIBLE_IP == "dhcp" ? "dhcp" : "${var.ANSIBLE_IP}"}"
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
      content     = tls_private_key.ansible_vm_key.private_key_openssh
      destination = ".ssh/id_rsa"
    }
    provisioner "remote-exec" {
        inline = [
        "chmod 600 /home/$USER/.ssh/id_rsa",
        ]
    }
}
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
