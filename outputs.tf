output "template_ID" {
  value = module.init_template.template_ID
}
output "ansible_vm_password" {
  value     = module.init_template.ansible_vm_password
  sensitive = true
}

