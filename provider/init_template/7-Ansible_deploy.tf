locals {
  Aedge_ipv4_address = flatten([
    for server, servers in proxmox_virtual_environment_vm.edge01.*.name : [
      for k, v in coalescelist(proxmox_virtual_environment_vm.edge01[server].ipv4_addresses, []) :
      v if length(regexall("^(lo|docker|veth).*", proxmox_virtual_environment_vm.edge01[server].network_interface_names[k])) == 0
    ]
  ])
  Bedge_ipv4_address = flatten([
    for server, servers in proxmox_virtual_environment_vm.edge.*.name : [
      for k, v in coalescelist(proxmox_virtual_environment_vm.edge[server].ipv4_addresses, []) :
      v if length(regexall("^(lo|docker|veth).*", proxmox_virtual_environment_vm.edge[server].network_interface_names[k])) == 0
    ]
  ])
  edge_ipv4_address = concat(local.Aedge_ipv4_address, local.Bedge_ipv4_address)
  master_ipv4_address = flatten([
    for server, servers in proxmox_virtual_environment_vm.master.*.name : [
      for k, v in coalescelist(proxmox_virtual_environment_vm.master[server].ipv4_addresses, []) :
      v if length(regexall("^(lo|docker|veth).*", proxmox_virtual_environment_vm.master[server].network_interface_names[k])) == 0
    ]
  ])
  etcd_ipv4_address = flatten([
    for server, servers in proxmox_virtual_environment_vm.etcd.*.name : [
      for k, v in coalescelist(proxmox_virtual_environment_vm.etcd[server].ipv4_addresses, []) :
      v if length(regexall("^(lo|docker|veth).*", proxmox_virtual_environment_vm.etcd[server].network_interface_names[k])) == 0
    ]
  ])
  worker_ipv4_address = flatten([
    for server, servers in proxmox_virtual_environment_vm.worker.*.name : [
      for k, v in coalescelist(proxmox_virtual_environment_vm.worker[server].ipv4_addresses, []) :
      v if length(regexall("^(lo|docker|veth).*", proxmox_virtual_environment_vm.worker[server].network_interface_names[k])) == 0
    ]
  ])
}
resource "local_file" "kube_inventory" {
  content = templatefile("provider/templates/kube_inventory.tmpl",
    {
      edge_ip             = local.edge_ipv4_address,
      edge_user           = "${concat([random_string.edge01_username.result], random_string.edge_username.*.result)}",
      master_ip           = local.master_ipv4_address,
      master_user         = random_string.master_username.*.result,
      no_init_master_ip   = slice(local.master_ipv4_address,1,var.MASTER_NUMBER_OF_VM),
      no_init_master_user = slice(random_string.master_username.*.result,1,var.MASTER_NUMBER_OF_VM),
      etcd_ip             = local.etcd_ipv4_address,
      etcd_user           = random_string.etcd_username.*.result,
      worker_ip           = local.worker_ipv4_address,
      worker_user         = random_string.worker_username.*.result,
    })
  filename = "ansible/inventory/kube_inventory"
}

resource "local_file" "tf_ansible_vars_file" {
  content = templatefile("provider/templates/tf_ansible_vars_file.tmpl",
    {
      edge_dns            = "${concat([proxmox_virtual_environment_vm.edge01.0.name], proxmox_virtual_environment_vm.edge.*.name)}",
      edge_ip             = local.edge_ipv4_address,
      edge_user           = "${concat([random_string.edge01_username.result], random_string.edge_username.*.result)}",
      master_dns          = proxmox_virtual_environment_vm.master.*.name
      master_ip           = local.master_ipv4_address,
      master_user         = random_string.master_username.*.result,
      no_init_master_dns  = slice(proxmox_virtual_environment_vm.master.*.name,1,var.MASTER_NUMBER_OF_VM),
      no_init_master_ip   = slice(local.master_ipv4_address,1,var.MASTER_NUMBER_OF_VM),
      no_init_master_user = slice(random_string.master_username.*.result,1,var.MASTER_NUMBER_OF_VM),
      etcd_dns            = proxmox_virtual_environment_vm.etcd.*.name
      etcd_ip             = local.etcd_ipv4_address,
      etcd_user           = random_string.etcd_username.*.result,
      worker_dns          = proxmox_virtual_environment_vm.worker.*.name
      worker_ip           = local.worker_ipv4_address,
      worker_user         = random_string.worker_username.*.result,

      tf_VIP_IP = "${var.EDGE_IP_PREFIX}${var.EDGE_IP_PREFIX_24 + 0}",
      tf_ansible_user = random_string.ansible_username.result,
    })
  filename = "ansible/vars/tf_ansible_vars_file.yml"
}
resource "null_resource" "ansible_file_transfer" {
  depends_on = [local_file.tf_ansible_vars_file, local_file.kube_inventory]
  connection {
    type     = "ssh"
    user     = random_string.ansible_username.result
    password = random_password.ansible_password.result
    private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
    host     = "${var.ANSIBLE_IP == "dhcp" ? "dhcp" : "${var.ANSIBLE_IP}"}"
    timeout = "10m"
  }

  provisioner "file" {
    source      = "ansible"
    destination = "/home/${ random_string.ansible_username.result }/ansible"
  }
}
resource "null_resource" "ansible_lauch" {
  depends_on = [null_resource.ansible_file_transfer]

  connection {
    type     = "ssh"
    user     = random_string.ansible_username.result
    password = random_password.ansible_password.result
    private_key = "${file(var.TEMPLATE_SSH_LOCAL_FILE)}"
    host     = "${var.ANSIBLE_IP == "dhcp" ? "dhcp" : "${var.ANSIBLE_IP}"}"
    timeout = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/${ random_string.ansible_username.result }/ansible/* /etc/ansible/",
      "ansible-playbook -i /etc/ansible/inventory/kube_inventory /etc/ansible/playbook/0_generate_certs.yml",
      "ansible-playbook -i /etc/ansible/inventory/kube_inventory --ssh-common-args='-o StrictHostKeyChecking=accept-new' /etc/ansible/playbook/0_install_dependencies.yml",
      "ansible-playbook -i /etc/ansible/inventory/kube_inventory /etc/ansible/playbook/1_kube_edge.yml",
      "ansible-playbook -i /etc/ansible/inventory/kube_inventory /etc/ansible/playbook/1_kube_etcd.yml",
      "ansible-playbook -i /etc/ansible/inventory/kube_inventory /etc/ansible/playbook/2_kube_master.yml",
    ]
  }
}
