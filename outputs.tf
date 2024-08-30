output "template_ID" {
  value = module.init_template.Template_Id
}
output "ansible_vm_password" {
  value     = module.generate_vms.ansible_vm_password
  sensitive = true
}

output "edge" {
  value = module.generate_vms.edge
}
output "master" {
  value = module.generate_vms.master
}
output "admin_user" {
  value = module.generate_vms.admin_user
  sensitive = true
}