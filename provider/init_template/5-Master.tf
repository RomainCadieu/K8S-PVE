
##################################################
# MASTER / CONTROL PANEL
##################################################
resource "proxmox_virtual_environment_vm" "master" {
    //depends_on = [null_resource.templatization, proxmox_virtual_environment_vm.edge01[0]]
    depends_on = [null_resource.templatization, proxmox_virtual_environment_vm.edge01[0],proxmox_virtual_environment_vm.etcd[0],proxmox_virtual_environment_vm.etcd[2]]
    count               =   var.MASTER_NUMBER_OF_VM
    name                =   format("Master%02d", count.index + 1)
    description         =   format("Control Pannel %02s, managed by Terraform",count.index + 1)
    tags                =   ["terraform", "Debian12", "master", "primary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   format("%2s%02s",var.MASTER_ID_PREFIX, count.index + 1)
    on_boot           = false
    started           = true

    clone {
        datastore_id    =   var.PROXMOX_VE_DEFAULT_DATASTORE
        node_name       =   var.PROXMOX_VE_DEFAULT_NODE
        retries         =   3 
        vm_id           =   proxmox_virtual_environment_vm.template_debian_vm[0].vm_id
        //vm_id           =   9101
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
                address =   "${var.MASTER_IP_PREFIX == "dhcp" ? "dhcp" : "${var.MASTER_IP_PREFIX}${var.MASTER_IP_PREFIX_24 + count.index + 1}${var.MASTER_MASK}"}"
                gateway =   var.MASTER_GW
            }
        }

        user_account {
            keys          = [trimspace(var.TEMPLATE_SSH),format("%s %s@%s",trimspace(tls_private_key.ansible_vm_key.public_key_openssh),random_string.ansible_username.result,proxmox_virtual_environment_vm.ansible[0].name)]
            password      = random_password.master_password[count.index].result
            username      = random_string.master_username[count.index].result
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
      type     = "ssh"
      user     = random_string.master_username[count.index].result
      password = random_password.master_password[count.index].result
      private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
      host     = "${var.MASTER_IP_PREFIX == "dhcp" ? "dhcp" : "${var.MASTER_IP_PREFIX}${var.MASTER_IP_PREFIX_24 + count.index + 1}"}"
    }
    provisioner "remote-exec" {
      inline = [
      "sudo deluser --remove-home ubuntu",
      "sudo swapoff -a", #Remove SWAP
      "sudo modprobe br_netfilter",
      "sudo su -c 'echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.ipv6.conf.all.forwarding=1' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.bridge.bridge-nf-call-arptables=1' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.bridge.bridge-nf-call-ip6tables=1' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.bridge.bridge-nf-call-iptables=1' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.bridge.bridge-nf-filter-pppoe-tagged=0' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.bridge.bridge-nf-filter-vlan-tagged=0' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.bridge.bridge-nf-pass-vlan-input-dev=0' | tee -a /etc/sysctl.conf'",
      "sudo sysctl -p",
      ]
    }
    provisioner "remote-exec" {
      inline = [
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo apt-get update -yqq",
      "sudo apt-get install --no-install-recommends -yqq apt-transport-https conntrack ca-certificates",
      "sudo su -c 'echo -e MaxSessions 100 | tee -a  /etc/ssh/sshd_config'",
      "sudo systemctl reload sshd",
      ]
    }
    provisioner "remote-exec" {
      inline = [
      "sudo su -c 'echo -e *    soft nofile 1048576 | tee -a /etc/security/limits.conf'", 
      "sudo su -c 'echo -e *    hard nofile 1048576 | tee -a /etc/security/limits.conf'",
      "sudo su -c 'echo -e root soft nofile 1048576 | tee -a /etc/security/limits.conf'",
      "sudo su -c 'echo -e root hard nofile 1048576 | tee -a /etc/security/limits.conf'",
      "sudo su -c 'echo -e session required pam_limits.so | tee -a  /etc/pam.d/common-session'",
      "sudo su -c 'echo 'fs.file-max=2097152' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'fs.nr_open=1048576' | tee -a /etc/sysctl.conf'",
      "sudo sysctl -p",
      ]
    }
    provisioner "remote-exec" {
      inline = [
      "sudo modprobe ip_conntrack",
      "sudo su -c 'echo -e 1024 65535 | tee -a /proc/sys/net/ipv4/ip_local_port_range'",
      "sudo su -c 'echo 'net.ipv4.tcp_tw_reuse=1' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.netfilter.nf_conntrack_max=1048576' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.nf_conntrack_max=1048576' | tee -a /etc/sysctl.conf'",
      "sudo su -c 'echo 'net.core.somaxconn=1048576' | tee -a /etc/sysctl.conf'",
      "sudo sysctl -p",
      ]
    }
    provisioner "remote-exec" {
      inline = [
        "sudo mkdir /etc/salt",
        "sudo su -c 'echo -e role: master >> /etc/salt/grains'",
      ]
    }
    provisioner "file" {
      content     = tls_private_key.master_vm_key[count.index].private_key_openssh
      destination = ".ssh/id_rsa"
    }
    provisioner "remote-exec" {
        inline = [
        "chmod 600 /home/$USER/.ssh/id_rsa",
        ]
    }
}

resource "random_string" "master_username" {
  count             = var.MASTER_NUMBER_OF_VM
  length            = 16
  special           = false
}
resource "random_password" "master_password" {
  count             = var.MASTER_NUMBER_OF_VM
  length            = 16
  override_special  = "_%@"
  special           = true
}
resource "tls_private_key" "master_vm_key" {
  count             = var.MASTER_NUMBER_OF_VM
  algorithm         = "RSA"
  rsa_bits          = 2048
}
