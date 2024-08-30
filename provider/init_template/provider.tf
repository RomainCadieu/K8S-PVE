terraform {
  required_providers {
    proxmox         = {
      source        = "bpg/proxmox"
      version       = "0.61.1"
    }
    ansible         = {
      source        = "ansible/ansible"
      version       = "1.3.0"
    }
  }
}

provider "proxmox" {
  #Read the doc of bpg/proxmox https://registry.terraform.io/providers/bpg/proxmox/latest/docs
  endpoint          = var.Proxmox.Endpoint
  username          = var.Proxmox.Username
  password          = var.Proxmox.Password
  insecure          = true

  ssh {
    agent           = false
  }
}
