variable "DEFAULT_USERNAME" {
    default = "ubuntu"
}

variable "WAN_GW" {
  type = string
  validation {
    condition     = can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",var.WAN_GW))
    error_message = "Must be a valid IPv4 CIDR block address."
  }  
    default = ""
}
variable "LAN_GW" {
  type = string
  validation {
    condition     = can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",var.LAN_GW))
    error_message = "Must be a valid IPv4 CIDR block address."
  }  
    default = ""
}
variable "LAN_MASK" {
    default = "/24"
}
variable "vlanID" {
  type = number
  default = "100" 
}
variable "WAN_IP_prefix" {
    default = ""
}
variable "LAN_IP_prefix" {
    default = ""
}
variable "Template_Id" {}
variable "VyOS_template_ID" {}
variable "WAN_IP_temp_prefix" {}
variable "WAN_IP_temp_suffix" {}

variable "Proxmox" {
  type = object({
    Endpoint        = string
    Ip              = string
    Username        = string
    Password        = string
    SSH_username    = string
    SSH_password    = string
    Node            = string
    Datastore       = string
  })
  default = {
    Endpoint        = "https://10.0.0.2:8006"
    Ip              = "10.0.0.2"
    Username        = "root@pam"
    Password        = "the-password-set-during-installation-of-proxmox-ve"
    SSH_username    = "root"
    SSH_password    = "the-password-set-during-installation-of-proxmox-ve"
    Node            = "pve"
    Datastore       = "local-lvm"
  }
}
variable "Template" {
  type = object({
    Ip_prefix       = string
    Ip_suffix       = number
    Mask            = string
    Id_prefix       = number
    SSH_key         = string # Casualy used with 'tls_private_key.template_debian_key.public_key_openssh'
    SSH_local_file  = string # Casualy used with 'C:/user/user/.ssh/pub_key'
  })
  default = {
    Ip_prefix       = "dhcp"
    Ip_suffix       = 0
    Mask            = ""
    Id_prefix       = 91
    SSH_key         = ""
    SSH_local_file  = ""
  }
}
variable "Edge" {
  type = object({
    Count           = number
    Ip_prefix       = string
    Ip_suffix       = number
    Mask            = string
    Id_prefix       = number
  })
  default = {
    Count           = 3
    Ip_prefix       = "dhcp"
    Ip_suffix       = 0
    Mask            = ""
    Id_prefix       = 92
  }
}
variable "Etcd" {
  type = object({
    Count           = number
    Ip_prefix       = string
    Ip_suffix       = number
    Mask            = string
    Id_prefix       = number
  })
  default = {
    Count           = 3
    Ip_prefix       = "dhcp"
    Ip_suffix       = 0
    Mask            = ""
    Id_prefix       = 93
  }
}
variable "Master" {
  type = object({
    Count           = number
    Ip_prefix       = string
    Ip_suffix       = number
    Mask            = string
    Id_prefix       = number
  })
  default = {
    Count           = 3
    Ip_prefix       = "dhcp"
    Ip_suffix       = 0
    Mask            = ""
    Id_prefix       = 94
  }
}
variable "Worker" {
  type = object({
    Count           = number
    Ip_prefix       = string
    Ip_suffix       = number
    Mask            = string
    Id_prefix       = number
  })
  default = {
    Count           = 3
    Ip_prefix       = "dhcp"
    Ip_suffix       = 0
    Mask            = ""
    Id_prefix       = 95
  }
}
variable "Ansible" {
  type = object({
    Ip              = string
    Mask            = string
    Id              = number
  })
  default = {
    Ip              = "dhcp"
    Mask            = ""
    Id              = 8101
  }
}
variable "VyOS" {
  type = object({
    Count           = number
    WAN_Ip_prefix   = string
    WAN_Ip_suffix   = number
    WAN_Mask        = string
    LAN_Ip_prefix   = string
    LAN_Ip_suffix   = number
    LAN_Mask        = string
    Id_prefix       = number
    WAN_VIp_suffix  = number
    LAN_VIp_suffix  = number
  })
  default = {
    Count           = 3
    WAN_Ip_prefix   = "dhcp"
    WAN_Ip_suffix   = 0
    WAN_Mask        = ""
    LAN_Ip_prefix   = "dhcp"
    LAN_Ip_suffix   = 0
    LAN_Mask        = ""
    Id_prefix       = 96
    WAN_VIp_suffix  = 130
    LAN_VIp_suffix  = 10
  }
}
variable "Admin_VPN" {
  type = object({
    Subnet_Prefix24 = string   
    Port            = number
  })
  default = {
    Subnet_Prefix24 = "10.1.0."   
    Port            = 51820
  }
}


#Software version
variable "VyOS_version" {
  type = object({
    Major           = string
    Branch          = string
    Minor           = number
  })
  default = {
    Major           = "1.5"
    Branch          = "rolling"
    Minor           = "202408090021"
  }
}
variable "Debian_version" {
  type = object({
    MajorID         = number
    MajorFQDN       = string
    MinorID         = string
  })
  default = {
    MajorID         = 12
    MajorFQDN       = "bookworm"
    MinorID         = "20240717-1811"
  }
}

