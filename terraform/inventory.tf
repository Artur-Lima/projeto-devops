# Ponte Terraform -> Ansible: gera o inventário com o IP da VM recém-criada.
locals {
  usuario_ssh = var.sistema == "Oracle Linux" ? "opc" : "ubuntu"
}

resource "local_file" "inventario_ansible" {
  filename        = "${path.module}/../ansible/inventory.terraform.ini"
  file_permission = "0644"
  content         = <<-EOT
    # Gerado pelo Terraform (terraform/inventory.tf) — não editar à mão.
    [app]
    ${var.nome}-vm ansible_host=${oci_core_instance.vm.public_ip} ansible_user=${local.usuario_ssh} ansible_ssh_private_key_file=${var.ssh_private_key_path}
  EOT
}
