
##################################################
# edge01
##################################################
resource "proxmox_virtual_environment_vm" "edge01" {
    depends_on = [null_resource.templatization, proxmox_virtual_environment_vm.ansible]
    count               =   1
    name                =   format("Edge%02s",count.index + 1)
    description         =   format("Edge%02s, managed by Terraform",count.index + 1)
    tags                =   ["terraform", "Debian12", "edge", "primary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   format("%2s%02s",var.EDGE_ID_PREFIX, count.index + 1)
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
                address =   "${var.EDGE_IP_PREFIX == "dhcp" ? "dhcp" : "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + count.index + 1}${var.EDGE_MASK}"}"
                gateway =   var.EDGE_GW
            }
        }

        user_account {
            keys          = [trimspace(var.TEMPLATE_SSH),format("%s %s@%s",trimspace(tls_private_key.ansible_vm_key.public_key_openssh),random_string.ansible_username.result,proxmox_virtual_environment_vm.ansible[0].name)]
            password      = random_password.edge01_password.result
            username      = random_string.edge01_username.result
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
        type     = "ssh"
        password      = random_password.edge01_password.result
        user      = random_string.edge01_username.result
        private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
        host     = "${var.EDGE_IP_PREFIX == "dhcp" ? "dhcp" : "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + count.index + 1}"}"
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
    provisioner "remote-exec" {
      inline = [
        "sudo mkdir /etc/salt",
        "sudo su -c 'echo -e role: edge >> /etc/salt/grains'",
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
# edge02
##################################################

resource "proxmox_virtual_environment_vm" "edge" {
    //depends_on = [null_resource.templatization, proxmox_virtual_environment_vm.edge01[0]]
    depends_on = [null_resource.templatization, proxmox_virtual_environment_vm.edge01[0]]
    count               =   var.EDGE_NUMBER_OF_VM - 1
    name                =   format("Edge%02s", count.index + 2)
    description         =   format("Edge%02s, managed by Terraform",count.index + 1)
    tags                =   ["terraform", "Debian12", "edge", "secondary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   format("%2s%02s",var.EDGE_ID_PREFIX, count.index + 2)
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
                address =   "${var.EDGE_IP_PREFIX == "dhcp" ? "dhcp" : "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + count.index + 2}${var.EDGE_MASK}"}"
                gateway =   var.EDGE_GW
            }
        }

        user_account {
            keys          = [trimspace(var.TEMPLATE_SSH),format("%s %s@%s",trimspace(tls_private_key.ansible_vm_key.public_key_openssh),random_string.ansible_username.result,proxmox_virtual_environment_vm.ansible[0].name)]
            password      = random_password.edge_password[count.index].result
            username      = random_string.edge_username[count.index].result
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
      type     = "ssh"
      user     = random_string.edge_username[count.index].result
      password = random_password.edge_password[count.index].result
      private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
      host     = "${var.EDGE_IP_PREFIX == "dhcp" ? "dhcp" : "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + count.index + 2}"}"
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
        "sudo su -c 'echo 'http_proxy=http://${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + 0}:8888' | tee -a  /etc/environment'",
        "sudo su -c 'echo 'https_proxy=http://${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + 0}:8888' | tee -a  /etc/environment'",
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
        "sudo su -c 'echo -e role: edge >> /etc/salt/grains'",
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
  count             = var.EDGE_NUMBER_OF_VM - 1
  length            = 16
  special           = false
}
resource "random_password" "edge_password" {
  count             = var.EDGE_NUMBER_OF_VM - 1
  length            = 16
  override_special  = "_%@"
  special           = true
}
resource "tls_private_key" "edge_vm_key" {
  count             = var.EDGE_NUMBER_OF_VM - 1
  algorithm         = "RSA"
  rsa_bits          = 2048
}











/*
resource "proxmox_virtual_environment_vm" "edge02" {
    depends_on = [null_resource.templatization]
    count               =   1
    name                =   format("Edge%02s",count.index + 2)
    description         =   format("Edge%02s, managed by Terraform",count.index + 2)
    tags                =   ["terraform", "Debian12", "edge", "primary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   format("%2s%02s",var.EDGE_ID_PREFIX, count.index + 2)
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
                address =   "${var.EDGE_IP_PREFIX == "dhcp" ? "dhcp" : "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + count.index + 1}${var.EDGE_MASK}"}"
                gateway =   var.EDGE_GW
            }
        }

        user_account {
            keys          = [trimspace(var.TEMPLATE_SSH)]
            password      = random_password.edge01_password.result
            username      = "ubuntu"
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
        type     = "ssh"
        user     = "ubuntu"
        password = random_password.edge02_password.result
        private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
        host     = "${var.EDGE_IP_PREFIX == "dhcp" ? "dhcp" : "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + count.index + 1}"}"
    }
    provisioner "remote-exec" {
        inline = [
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
        "sudo apt-get install --no-install-recommends -yqq apt-transport-https conntrack ca-certificates tinyproxy ",
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


}

/*
resource "scaleway_server" "edge02" {
  depends_on = [scaleway_server.edge01]

  count       = 1
  name        = "edge02"
  image       = data.scaleway_image.ubuntu.id
  bootscript  = data.scaleway_bootscript.bootscript.id
  type        = var.edge_type
  state       = "running"
  enable_ipv6 = true
  tags        = ["edge", "secondary"]

  connection {
    type                = "ssh"
    host                = self.private_ip
    user                = var.ssh_user
    private_key         = file(var.ssh_private_key)
    agent               = false
    bastion_host        = scaleway_server.edge01.0.public_ip
    bastion_user        = var.ssh_user
    bastion_private_key = file(var.ssh_private_key)
    timeout             = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "modprobe br_netfilter",
      "echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.conf",
      "echo 'net.ipv6.conf.all.forwarding=1' | tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-arptables=1' | tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-ip6tables=1' | tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-call-iptables=1' | tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-filter-pppoe-tagged=0' | tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-filter-vlan-tagged=0' | tee -a /etc/sysctl.conf",
      "echo 'net.bridge.bridge-nf-pass-vlan-input-dev=0' | tee -a /etc/sysctl.conf",
      "sysctl -p",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'http_proxy=http://${scaleway_server.edge01.0.private_ip}:8888' | tee -a  /etc/environment",
      "echo 'https_proxy=http://${scaleway_server.edge01.0.private_ip}:8888' | tee -a  /etc/environment",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "rm -rf /var/lib/apt/lists/*",
      "apt-get update -yqq",
      "apt-get install --no-install-recommends -yqq apt-transport-https conntrack ca-certificates ${join(" ", var.apt_packages)}",
      "echo 'MaxSessions 100' | tee -a  /etc/ssh/sshd_config",
      "systemctl reload sshd",
    ]
  }

 provisioner "remote-exec" {
    inline = [
      "echo '*    soft nofile 1048576' | tee -a /etc/security/limits.conf", 
      "echo '*    hard nofile 1048576' | tee -a /etc/security/limits.conf",
      "echo 'root soft nofile 1048576' | tee -a /etc/security/limits.conf",
      "echo 'root hard nofile 1048576' | tee -a /etc/security/limits.conf",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'session required pam_limits.so' | tee -a  /etc/pam.d/common-session",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'fs.file-max=2097152' | tee -a /etc/sysctl.conf",
      "echo 'fs.nr_open=1048576' | tee -a /etc/sysctl.conf",
      "sysctl -p",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "modprobe ip_conntrack",
      "echo '1024 65535' | tee -a /proc/sys/net/ipv4/ip_local_port_range",
      "echo 'net.ipv4.tcp_tw_reuse=1' | tee -a /etc/sysctl.conf",
      "echo 'net.netfilter.nf_conntrack_max=1048576' | tee -a /etc/sysctl.conf",
      "echo 'net.nf_conntrack_max=1048576' | tee -a /etc/sysctl.conf",
      "echo 'net.core.somaxconn=1048576' | tee -a /etc/sysctl.conf",
      "sysctl -p",
    ]
  }

  provisioner "file" {
    content     = "role: edge"
    destination = "/etc/salt/grains"
  }
} 
*/

