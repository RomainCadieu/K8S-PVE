
##################################################
# MASTER / CONTROL PANEL
##################################################
resource "proxmox_virtual_environment_vm" "master" {
  depends_on = [proxmox_virtual_environment_vm.edge01[0],proxmox_virtual_environment_vm.etcd[0],proxmox_virtual_environment_vm.etcd[2]]
  count               =   var.Master.Count
  name                =   format("Master%02d", count.index + 1)
  description         =   format("Control Pannel %02s, managed by Terraform",count.index + 1)
  tags                =   ["Terraform", "Debian12", "Master"]
  node_name           =   var.Proxmox.Node
  vm_id               =   format("%2s%02s",var.Master.Id_prefix, count.index + 1)
  on_boot             =   false
  started             =   true

  clone {
    datastore_id    =   var.Proxmox.Datastore
    node_name       =   var.Proxmox.Node
    retries         =   3 
    vm_id           =   var.Template_Id
    full            =   true
  }
  cpu {   
    cores           = 2
  }
  memory {
    dedicated       = 2048
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
        address =   "${var.Master.Ip_prefix == "dhcp" ? "dhcp" : "${var.Master.Ip_prefix}${var.Master.Ip_suffix + count.index + 1}${var.Master.Mask}"}"
        gateway =   var.LAN_GW
      }
    }
    ip_config {
      ipv4 {
        address     =   "${ var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix + var.Edge.Count + var.Etcd.Count + 1 + count.index }${var.VyOS.LAN_Mask}"
      }
    }
    user_account {
      keys          = [trimspace(var.Template.SSH_key),format("%s %s@%s",trimspace(tls_private_key.ansible_vm_key.public_key_openssh),random_string.ansible_username.result,proxmox_virtual_environment_vm.ansible[0].name)]
      password      = random_password.master_password[count.index].result
      username      = random_string.master_username[count.index].result
    }
    datastore_id    = var.Proxmox.Datastore
  }
  connection {
    type     = "ssh"
    user     = random_string.master_username[count.index].result
    password = random_password.master_password[count.index].result
    private_key = "${file(var.Template.SSH_local_file)}"
    host     = "${ var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix + var.Edge.Count + var.Etcd.Count + 1 + count.index }"
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
  count             = var.Master.Count
  length            = 16
  special           = false
}
resource "random_password" "master_password" {
  count             = var.Master.Count
  length            = 16
  override_special  = "_%@"
  special           = true
}
resource "tls_private_key" "master_vm_key" {
  count             = var.Master.Count
  algorithm         = "RSA"
  rsa_bits          = 2048
}
