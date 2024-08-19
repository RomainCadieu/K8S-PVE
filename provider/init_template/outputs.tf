output "template_debian_password" {
  value     = random_password.template_debian_password.result
  sensitive = true
}

output "template_debian_private_key" {
  value     = tls_private_key.template_debian_key.private_key_pem
  sensitive = true
}

output "template_debian_public_key" {
  value = tls_private_key.template_debian_key.public_key_openssh
}

output "template_ID" {
  value = proxmox_virtual_environment_vm.template_debian_vm[0].vm_id
}

