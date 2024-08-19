//Proxmox Settings
variable "PROXMOX_VE_ENDPOINT" {
    default = "https://10.0.0.2:8006"
}

variable "PROXMOX_VE_IP" {
    default = "10.0.0.2"
}

variable "PROXMOX_VE_USERNAME" {
    default = "root@pam"
}

variable "PROXMOX_VE_PASSWORD" {
    default = "the-password-set-during-installation-of-proxmox-ve"
}

variable "PROXMOX_VE_SSH_USERNAME" {
    default = "root"
}

variable "PROXMOX_VE_SSH_PASSWORD" {
    default = "the-password-set-during-installation-of-proxmox-ve"
}

variable "PROXMOX_VE_DEFAULT_NODE" {
    default = "pve"
}

variable "PROXMOX_VE_DEFAULT_DATASTORE" {
    default = "local-lvm"
}

variable "TEMPLATE_IP" {
    default = "dhcp"
}
variable "TEMPLATE_ID_PREFIX" {
    default = 91
}
variable "TEMPLATE_MASK" {
    default = ""
}
variable "TEMPLATE_GW" {
    default = ""
}
variable "TEMPLATE_SSH" {
    default = ""
    # Casualy used with 'tls_private_key.template_debian_key.public_key_openssh'
}
variable "TEMPLATE_SSH_LOCAL_FILE" {
    default = ""
    # Casualy used with 'C:/user/user/.ssh/pub_key'
}

variable "DEFAULT_USERNAME" {
    default = "ubuntu"
}

variable "EDGE_NUMBER_OF_VM" {
    default = 3
}
variable "EDGE_IP_PREFIX" {
    default = "dhcp"
}
variable "EDGE_IP_PREFIX_24" {
    default = ""
    #Not used in case of DHCP
}
variable "EDGE_GW" {
    default = ""
}
variable "EDGE_MASK" {
    default = ""
}
variable "EDGE_ID_PREFIX" {
    default = 96
}

variable "ETCD_NUMBER_OF_VM" {
    default = 3
}
variable "ETCD_IP_PREFIX" {
    default = "dhcp"
}
variable "ETCD_IP_PREFIX_24" {
    default = ""
    #Not used in case of DHCP
}
variable "ETCD_GW" {
    default = ""
}
variable "ETCD_MASK" {
    default = ""
}
variable "ETCD_ID_PREFIX" {
    default = 97
}

variable "MASTER_NUMBER_OF_VM" {
    default = 3
}
variable "MASTER_IP_PREFIX" {
    default = "dhcp"
}
variable "MASTER_IP_PREFIX_24" {
    default = ""
    #Not used in case of DHCP
}
variable "MASTER_GW" {
    default = ""
}
variable "MASTER_MASK" {
    default = ""
}
variable "MASTER_ID_PREFIX" {
    default = 98
}

variable "WORKER_NUMBER_OF_VM" {
    default = 3
}
variable "WORKER_IP_PREFIX" {
    default = "dhcp"
}
variable "WORKER_IP_PREFIX_24" {
    default = ""
    #Not used in case of DHCP
}
variable "WORKER_GW" {
    default = ""
}
variable "WORKER_MASK" {
    default = ""
}
variable "WORKER_ID_PREFIX" {
    default = 99
}
variable "ANSIBLE_IP" {
    default = "dhcp"
}
variable "ANSIBLE_GW" {
    default = ""
}
variable "ANSIBLE_MASK" {
    default = ""
}
variable "ANSIBLE_ID" {
    default = 8101
}