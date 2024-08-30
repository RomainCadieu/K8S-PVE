resource "null_resource" "destroy_admin_net" {
  depends_on = [null_resource.ansible_lauch]

  connection {
    type     = "ssh"
    user     = var.Proxmox.SSH_username
    password = var.Proxmox.SSH_password
    host     = var.Proxmox.Ip
  }
  provisioner "remote-exec" {
    inline = [
      "bash -c 'pvesh set /nodes/${var.Proxmox.Node}/qemu/${var.Ansible.Id}/config --delete net1'",
      "bash -c 'for ((i=1;i<=${ var.Edge.Count };i++)); do pvesh set /nodes/${var.Proxmox.Node}/qemu/$(printf '%02d%02d' ${var.Edge.Id_prefix} $i)/config --delete net1; done'",
      "bash -c 'for ((i=1;i<=${ var.Etcd.Count };i++)); do pvesh set /nodes/${var.Proxmox.Node}/qemu/$(printf '%02d%02d' ${var.Etcd.Id_prefix} $i)/config --delete net1; done'",
      "bash -c 'for ((i=1;i<=${ var.Master.Count };i++)); do pvesh set /nodes/${var.Proxmox.Node}/qemu/$(printf '%02d%02d' ${var.Master.Id_prefix} $i)/config --delete net1; done'",
      "bash -c 'for ((i=1;i<=${ var.Worker.Count };i++)); do pvesh set /nodes/${var.Proxmox.Node}/qemu/$(printf '%02d%02d' ${var.Worker.Id_prefix} $i)/config --delete net1; done'",
    ]
  }
}
