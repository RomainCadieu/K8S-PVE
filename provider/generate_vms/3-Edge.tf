
##################################################
# edge01
##################################################
resource "proxmox_virtual_environment_vm" "edge01" {
  depends_on = [proxmox_virtual_environment_vm.ansible]
  count               =   1
  name                =   format("Edge%02s",count.index + 1)
  description         =   format("Edge%02s, managed by Terraform",count.index + 1)
  tags                =   ["Terraform", "Debian12", "Edge", "Primary"]
  node_name           =   var.Proxmox.Node
  vm_id               =   format("%2s%02s",var.Edge.Id_prefix, count.index + 1)
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
    cores           = 1
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
        address =   "${var.Edge.Ip_prefix == "dhcp" ? "dhcp" : "${var.Edge.Ip_prefix}${var.Edge.Ip_suffix + count.index + 1}${var.Edge.Mask}"}"
        gateway =   var.LAN_GW
      }
    }
    ip_config {
      ipv4 {
        address     =   "${var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix + 1}${var.VyOS.LAN_Mask}"
      }
    }

    user_account {
      keys          = [trimspace(var.Template.SSH_key),format("%s %s@%s",trimspace(tls_private_key.ansible_vm_key.public_key_openssh),random_string.ansible_username.result,proxmox_virtual_environment_vm.ansible[0].name)]
      password      = random_password.edge01_password.result
      username      = random_string.edge01_username.result
    }
    datastore_id    = var.Proxmox.Datastore
  }
  connection {
    type          = "ssh"
    password      = random_password.edge01_password.result
    user          = random_string.edge01_username.result
    private_key   = "${file(var.Template.SSH_local_file)}"
    host          = "${var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix + 1}"
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
      "sudo apt-get install --no-install-recommends -yqq apt-transport-https conntrack ca-certificates tinyproxy -o DPkg::Lock::Timeout=60",
      "sudo su -c 'echo -e MaxSessions 100 | tee -a  /etc/ssh/sshd_config'",
      "sudo systemctl reload sshd",
      "sudo systemctl enable tinyproxy",
      "sudo su -c 'echo -e Allow 127.0.0.1 | tee -a  /etc/tinyproxy.conf'",
      "sudo su -c 'echo -e Allow 192.168.0.0/16 | tee -a  /etc/tinyproxy.conf'",
      "sudo su -c 'echo -e Allow 172.16.0.0/12 | tee -a  /etc/tinyproxy.conf'",
      "sudo su -c 'echo -e Allow 10.0.0.0/8 | tee -a  /etc/tinyproxy.conf'",
      "sudo systemctl daemon-reload",
      "sudo systemctl start tinyproxy.service",
      "sudo systemctl is-active tinyproxy.service",
      "sudo su -c 'echo 'http_proxy=http://localhost:8888' | tee -a  /etc/environment'",
      "sudo su -c 'echo 'https_proxy=http://localhost:8888' | tee -a  /etc/environment'",
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
      "sudo systemctl restart tinyproxy",
      "sudo systemctl status tinyproxy --no-pager",
    ]
  }
  provisioner "file" {
    content     = tls_private_key.edge01_vm_key.private_key_openssh
    destination = ".ssh/id_rsa"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/$USER/.ssh/id_rsa",
    ]
  }
}

resource "random_string" "edge01_username" {
  length            = 16
  special           = false
}
resource "random_password" "edge01_password" {
  length            = 16
  override_special  = "_%@"
  special           = true
}
resource "tls_private_key" "edge01_vm_key" {
  algorithm         = "RSA"
  rsa_bits          = 2048
}


 
##################################################
# edges
##################################################

resource "proxmox_virtual_environment_vm" "edge" {
  depends_on = [proxmox_virtual_environment_vm.edge01[0]]
  count               =   var.Edge.Count - 1
  name                =   format("Edge%02s", count.index + 2)
  description         =   format("Edge%02s, managed by Terraform",count.index + 1)
  tags                =   ["Terraform", "Debian12", "Edge", "Secondary"]
  node_name           =   var.Proxmox.Node
  vm_id               =   format("%2s%02s",var.Edge.Id_prefix, count.index + 2)
  on_boot           = false
  started           = true

  clone {
    datastore_id    =   var.Proxmox.Datastore
    node_name       =   var.Proxmox.Node
    retries         =   3 
    vm_id           =   var.Template_Id
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
        address =   "${var.Edge.Ip_prefix == "dhcp" ? "dhcp" : "${var.Edge.Ip_prefix}${var.Edge.Ip_suffix + count.index + 2}${var.Edge.Mask}"}"
        gateway =   var.LAN_GW
      }
    }
    ip_config {
      ipv4 {
        address     =   "${var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix + 2 + count.index }${var.VyOS.LAN_Mask}"
      }
    }
    user_account {
      keys          = [trimspace(var.Template.SSH_key),format("%s %s@%s",trimspace(tls_private_key.ansible_vm_key.public_key_openssh),random_string.ansible_username.result,proxmox_virtual_environment_vm.ansible[0].name)]
      password      = random_password.edge_password[count.index].result
      username      = random_string.edge_username[count.index].result
    }
    datastore_id    = var.Proxmox.Datastore
  }
  connection {
    type     = "ssh"
    user     = random_string.edge_username[count.index].result
    password = random_password.edge_password[count.index].result
    private_key = "${file(var.Template.SSH_local_file)}"
    host     = "${var.WAN_IP_temp_prefix}${var.WAN_IP_temp_suffix + 2 + count.index }"
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
      "sudo su -c 'echo 'http_proxy=http://${var.Edge.Ip_prefix}${var.Edge.Ip_suffix + 0}:8888' | tee -a  /etc/environment'",
      "sudo su -c 'echo 'https_proxy=http://${var.Edge.Ip_prefix}${var.Edge.Ip_suffix + 0}:8888' | tee -a  /etc/environment'",
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
    content     = tls_private_key.edge_vm_key[count.index].private_key_openssh
    destination = ".ssh/id_rsa"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/$USER/.ssh/id_rsa",
    ]
  }
}


resource "random_string" "edge_username" {
  count             = var.Edge.Count - 1
  length            = 16
  special           = false
}
resource "random_password" "edge_password" {
  count             = var.Edge.Count - 1
  length            = 16
  override_special  = "_%@"
  special           = true
}
resource "tls_private_key" "edge_vm_key" {
  count             = var.Edge.Count - 1
  algorithm         = "RSA"
  rsa_bits          = 2048
}


