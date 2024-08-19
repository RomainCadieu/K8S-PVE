
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
  source = "./provider/init_template"

  PROXMOX_VE_ENDPOINT             =   var.PROXMOX_VE_ENDPOINT         
  PROXMOX_VE_USERNAME             =   var.PROXMOX_VE_USERNAME         
  PROXMOX_VE_PASSWORD             =   var.PROXMOX_VE_PASSWORD         
  PROXMOX_VE_DEFAULT_NODE         =   var.PROXMOX_VE_DEFAULT_NODE     
  PROXMOX_VE_DEFAULT_DATASTORE    =   var.PROXMOX_VE_DEFAULT_DATASTORE
  PROXMOX_VE_IP                   =   var.PROXMOX_VE_IP               
  PROXMOX_VE_SSH_USERNAME         =   var.PROXMOX_VE_SSH_USERNAME     
  PROXMOX_VE_SSH_PASSWORD         =   var.PROXMOX_VE_SSH_PASSWORD    

  TEMPLATE_IP                     =   var.TEMPLATE_IP                 
  TEMPLATE_GW                     =   var.TEMPLATE_GW                 
  TEMPLATE_MASK                   =   var.TEMPLATE_MASK               
  TEMPLATE_SSH                    =   var.TEMPLATE_SSH                
  TEMPLATE_SSH_LOCAL_FILE         =   var.TEMPLATE_SSH_LOCAL_FILE
  TEMPLATE_ID_PREFIX              =   var.TEMPLATE_ID_PREFIX

  DEFAULT_USERNAME                =   var.DEFAULT_USERNAME

  EDGE_NUMBER_OF_VM               =   var.EDGE_NUMBER_OF_VM
  EDGE_IP_PREFIX                  =   var.EDGE_IP_PREFIX
  EDGE_GW                         =   var.EDGE_GW  
  EDGE_MASK                       =   var.EDGE_MASK
  EDGE_ID_PREFIX                  =   var.EDGE_ID_PREFIX
  EDGE_IP_PREFIX_24               =   var.EDGE_IP_PREFIX_24

  ETCD_NUMBER_OF_VM               =   var.ETCD_NUMBER_OF_VM
  ETCD_IP_PREFIX                  =   var.ETCD_IP_PREFIX     
  ETCD_IP_PREFIX_24               =   var.ETCD_IP_PREFIX_24
  ETCD_ID_PREFIX                  =   var.ETCD_ID_PREFIX  
  ETCD_GW                         =   var.ETCD_GW            
  ETCD_MASK                       =   var.ETCD_MASK   

  MASTER_NUMBER_OF_VM             =   var.MASTER_NUMBER_OF_VM
  MASTER_IP_PREFIX                =   var.MASTER_IP_PREFIX   
  MASTER_IP_PREFIX_24             =   var.MASTER_IP_PREFIX_24
  MASTER_ID_PREFIX                =   var.MASTER_ID_PREFIX
  MASTER_GW                       =   var.MASTER_GW          
  MASTER_MASK                     =   var.MASTER_MASK     

  WORKER_NUMBER_OF_VM             =   var.WORKER_NUMBER_OF_VM
  WORKER_IP_PREFIX                =   var.WORKER_IP_PREFIX   
  WORKER_IP_PREFIX_24             =   var.WORKER_IP_PREFIX_24
  WORKER_ID_PREFIX                =   var.WORKER_ID_PREFIX
  WORKER_GW                       =   var.WORKER_GW          
  WORKER_MASK                     =   var.WORKER_MASK        

  ANSIBLE_IP                      =   var.ANSIBLE_IP
  ANSIBLE_GW                      =   var.ANSIBLE_GW
  ANSIBLE_MASK                    =   var.ANSIBLE_MASK
  ANSIBLE_ID                      =   var.ANSIBLE_ID

}