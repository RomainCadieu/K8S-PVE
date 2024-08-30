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





output "Template_Id" {
  value = "${format("%2s%02s",var.Template.Id_prefix, 01)}"
}
output "VyOS_template_ID" {
  value = local.VyOS_template_ID
}
