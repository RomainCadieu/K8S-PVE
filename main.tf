
######## Début algo ########

/*
0. Faire un switch pour les modules

Module init_template : Création du modèle utilisé pour toutes les VMs
    1. Récupérer la cloud init image de Debian sur Proxmox.           [ok]
    2. Créer un dummy template de VM pour toutes les VMs à produire.  [ok]

Module 2 : Création du stack K8S
    3. Générer l'ensemble des VMs.
      4. Installation des différents logiciels sur les VMs. {Saltstack, Wireguard,}
    5. Lancer l'ensemble des scripts saltstack

Module 3 : Création des pods K8S. (wireguard basshtion )
Module 4 : Modifier le stack
*/

module "init_template" {
  /*
    This module is responsible for the creation of templates for the VMs used in other modules.
  */
  source = "./provider/init_template"

  Proxmox                         =   var.Proxmox
  Template                        =   var.Template
  Ansible                         =   var.Ansible
  WAN_GW                          =   var.WAN_GW

}
module "generate_vms" {
  /*
    This module enable to deploy all of the VMs and generate K8S cluster.
  */
  source = "./provider/generate_vms"  

  Proxmox                         =   var.Proxmox
  Template                        =   var.Template
  Edge                            =   var.Edge
  Etcd                            =   var.Etcd
  Master                          =   var.Master
  Worker                          =   var.Worker
  Ansible                         =   var.Ansible
  VyOS                            =   var.VyOS
  # Admin VPN task may be in a separate module in the future to easily CRUD users. It's future intent because it might be a security feature not to enable that. I don't really know :/ 
  Admin_VPN                       =   var.Admin_VPN
               
  DEFAULT_USERNAME                =   var.DEFAULT_USERNAME
  WAN_IP_prefix                   =   var.WAN_IP_prefix
  LAN_IP_prefix                   =   var.LAN_IP_prefix
  LAN_MASK                        =   var.LAN_MASK
  LAN_GW                          =   var.LAN_GW
  WAN_IP_temp_prefix              =   var.WAN_IP_temp_prefix
  WAN_IP_temp_suffix              =   var.WAN_IP_temp_suffix
  WAN_GW                          =   var.WAN_GW  
  Template_Id                     =   module.init_template.Template_Id
  VyOS_template_ID                =   module.init_template.VyOS_template_ID
}