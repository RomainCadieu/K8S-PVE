output "edge" {
  value = local.edge_ipv4_address
}
output "master" {
  value = local.master_ipv4_address
}
output "admin_user" {
  value = data.wireguard_config_document.admin_user.conf
  sensitive = true
}