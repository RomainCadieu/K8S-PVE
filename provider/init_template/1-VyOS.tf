resource "proxmox_virtual_environment_vm" "VyOS_TEST" {
    depends_on = [null_resource.VyOS_CI2]
    count               =   1
    name                =   "VyOSTEST"
    description         =   "VyOS_TEST, managed by Terraform"
    tags                =   ["terraform", "Debian12", "Ansible", "primary"]
    node_name           =   var.PROXMOX_VE_DEFAULT_NODE
    vm_id               =   9501
    on_boot           = false
    started           = true

    clone {
        datastore_id    =   var.PROXMOX_VE_DEFAULT_DATASTORE
        node_name       =   var.PROXMOX_VE_DEFAULT_NODE
        retries         =   3 
        vm_id           =   "${format("%2s%02s",var.TEMPLATE_ID_PREFIX, 02)}"
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
                address =   "192.168.1.198/24"
                gateway =   "192.168.1.1"
            }
        }

        user_account {
            keys      = [trimspace(var.TEMPLATE_SSH)]
            username      = ""
            password  = ""
        }
        datastore_id    = var.PROXMOX_VE_DEFAULT_DATASTORE
    }
    connection {
        type     = "ssh"
        user     = ""
        password = ""
        private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
        host     = "192.168.1.199"
    }
}