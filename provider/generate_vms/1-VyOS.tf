    ###################################################
    #               Deploy router VyOS                #
    ###################################################

#_________________________________________________________#
#   Create a VLAN on each pve nodes for teh LAN network   #
#‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾#
data "proxmox_virtual_environment_nodes" "pve_nodes" {}

resource "proxmox_virtual_environment_network_linux_vlan" "kubernetes_vlan" {
  for_each              = toset(data.proxmox_virtual_environment_nodes.pve_nodes.names)
  node_name             = each.key
  name                  = "kubernetes_vlan"
  interface             = "vmbr0"
  vlan                  = var.vlanID
  comment               = "VLAN for kubernetes"
}

#   Verify if VyOS template is set. If not module init_template may not have it created.    #

resource "null_resource" "wait_before_VyOS" {
  connection {
    type                = "ssh"
    user                = var.Proxmox.SSH_username
    password            = var.Proxmox.SSH_password
    host                = var.Proxmox.Ip
  }
  provisioner "remote-exec" {
    inline = [
      "while ! grep 'template' /etc/pve/qemu-server/${var.Template.Id_prefix}02.conf > /dev/null; do sleep 2s; done"
    ]
  }
}

#_________________________________________________________#
#       Deploy VyOS VMs with minimal configuration        #
#‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾#


resource "proxmox_virtual_environment_vm" "VyOS_router" {
  depends_on = [ null_resource.wait_before_VyOS ]
  count               =   var.VyOS.Count
  name                =   format("VyOS%02d", count.index + 1)
  description         =   format("VyOS%02s, managed by Terraform",count.index + 1)
  tags                =   ["Terraform", "Debian12", "VyOS"]
  node_name           =   var.Proxmox.Node
  vm_id               =   format("%2s%02s",var.VyOS.Id_prefix, count.index + 1)
  on_boot             =   false
  started             =   true

  clone {
    datastore_id    =   var.Proxmox.Datastore
    node_name       =   var.Proxmox.Node
    retries         =   3 
    vm_id           =   var.VyOS_template_ID
    full            =   true
  }
  cpu {   
    cores           = 1
  }
  memory {
    dedicated       = 1024
  }
  network_device {
    bridge          = "vmbr0"
  }
  network_device {
    bridge          = "vmbr0"
    vlan_id         = "100"
  }
  disk {
    datastore_id    =   var.Proxmox.Datastore
    interface       =   "scsi0"
    size            =   10
    file_format     =   "raw"
  }
  agent {
    enabled         =   true
  }

  initialization {
    ip_config {
      ipv4 {
        address =   "${var.VyOS.WAN_Ip_suffix == "dhcp" ? "dhcp" : "${var.VyOS.WAN_Ip_prefix}${var.VyOS.WAN_Ip_suffix + count.index + 1}${var.VyOS.WAN_Mask}"}"
        gateway =   "${var.WAN_GW}"
      }
    }
    ip_config {
      ipv4 {
        address =   "${var.VyOS.LAN_Ip_prefix}${ count.index + 1}${var.VyOS.LAN_Mask}"
      }
    }
    user_account {
      keys        =   [trimspace(var.Template.SSH_key)]
      username    =   random_string.VyOS_username[count.index].result
      password    =   random_password.VyOS_password[count.index].result
    }
    datastore_id    =   var.Proxmox.Datastore
  }
  connection {
    type     = "ssh"
    user     = random_string.VyOS_username[count.index].result
    password = random_password.VyOS_password[count.index].result
    private_key = "${file(var.Template.SSH_local_file)}"
    host     = "${var.VyOS.WAN_Ip_suffix == "dhcp" ? "dhcp" : "${var.VyOS.WAN_Ip_prefix}${var.VyOS.WAN_Ip_suffix + count.index + 1}"}"
  }

#   Create a .sh file to run every VyOS command. This script create a VRRP address and a SNAT for LAN to connect to WAN network   #

  provisioner "remote-exec" {
    inline = [
      "echo 'source /opt/vyatta/etc/functions/script-template' >> vyos_config.sh",
      "echo 'configure' >> vyos_config.sh",
      "if ((${count.index + 1 } <= ((${ var.VyOS.Count }+1)/2))); then echo 'set high-availability vrrp group LAN-${count.index + 1} priority 200' >> vyos_config.sh; fi",
      "if ((${count.index + 1 } <= ((${ var.VyOS.Count }+1)/2))); then echo 'set high-availability vrrp group WAN-${count.index + 1} priority 200' >> vyos_config.sh; fi",
      "for ((i=1;i<=((${ var.VyOS.Count }+1)/2);i++)); do echo set high-availability vrrp group LAN-$(echo $i) vrid $(echo $i)1 >> vyos_config.sh; echo set high-availability vrrp group LAN-$(echo $i) interface eth1 >> vyos_config.sh; declare -i LAN=${var.VyOS.LAN_VIp_suffix}+$(echo $i); echo set high-availability vrrp group LAN-$(echo $i) address ${var.VyOS.LAN_Ip_prefix}$(echo $LAN)${var.VyOS.LAN_Mask} >> vyos_config.sh; echo set high-availability vrrp group LAN-$(echo $i) rfc3768-compatibility >> vyos_config.sh; done",
      "for ((i=1;i<=((${ var.VyOS.Count }+1)/2);i++)); do echo set high-availability vrrp group WAN-$(echo $i) vrid $(echo $i)0 >> vyos_config.sh; echo set high-availability vrrp group WAN-$(echo $i) interface eth0 >> vyos_config.sh; declare -i WAN=${var.VyOS.WAN_VIp_suffix}+$(echo $i); echo set high-availability vrrp group WAN-$(echo $i) address ${var.VyOS.WAN_Ip_prefix}$(echo $WAN)${var.VyOS.WAN_Mask} >> vyos_config.sh; echo set high-availability vrrp group WAN-$(echo $i) rfc3768-compatibility >> vyos_config.sh; done",
      "echo 'set nat source rule 10 translation address masquerade' >> vyos_config.sh",
      "echo 'set nat source rule 10 source address ${var.VyOS.LAN_Ip_prefix}0/24' >> vyos_config.sh",
      "echo 'set nat source rule 10 outbound-interface name eth0' >> vyos_config.sh",
      "echo 'set interfaces wireguard wg01 address ${var.Admin_VPN.Subnet_Prefix24}1/24' >> vyos_config.sh",
      "echo 'set interfaces wireguard wg01 port ${var.Admin_VPN.Port}' >> vyos_config.sh",
      "echo 'set interfaces wireguard wg01 private-key ${wireguard_asymmetric_key.admin_vpn.private_key}' >> vyos_config.sh",
      "echo 'set interfaces wireguard wg01 peer to-admin public-key ${wireguard_asymmetric_key.admin_user.public_key}' >> vyos_config.sh",
      "echo 'set interfaces wireguard wg01 peer to-admin preshared-key ${wireguard_preshared_key.admin_user.key}' >> vyos_config.sh",
      "echo 'set interfaces wireguard wg01 peer to-admin allowed-ips ${var.Admin_VPN.Subnet_Prefix24}2/32' >> vyos_config.sh",
      
      "echo 'commit' >> vyos_config.sh",
      "echo 'save' >> vyos_config.sh",
      "echo 'exit' >> vyos_config.sh",
      "vbash vyos_config.sh",
      "rm vyos_config.sh"
    ]
  }
}
data "wireguard_config_document" "admin_user" {
  addresses = [
    "${var.Admin_VPN.Subnet_Prefix24}2/24",
  ]
  private_key = wireguard_asymmetric_key.admin_user.private_key
  listen_port = var.Admin_VPN.Port

  peer {
    public_key    = wireguard_asymmetric_key.admin_vpn.public_key
    preshared_key = wireguard_preshared_key.admin_user.key
    allowed_ips = [
      "${var.VyOS.LAN_Ip_prefix}0${var.VyOS.LAN_Mask}",
    ]
    endpoint = "${var.VyOS.WAN_Ip_prefix}${var.VyOS.WAN_Ip_suffix + 1}:${var.Admin_VPN.Port}"
  }
}

#___________________________________________________________#
# Generate random values for username, password and SSH key #
#‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾#

resource "random_string" "VyOS_username" {
  count             = var.VyOS.Count
  length            = 16
  special           = false
}
resource "random_password" "VyOS_password" {
  count             = var.VyOS.Count
  length            = 16
  override_special  = "_%@"
  special           = true
}
resource "tls_private_key" "VyOS_vm_key" {
  count             = var.VyOS.Count
  algorithm         = "RSA"
  rsa_bits          = 2048
}
resource "wireguard_asymmetric_key" "admin_vpn" {}

resource "wireguard_asymmetric_key" "admin_user" {}
resource "wireguard_preshared_key" "admin_user" {}