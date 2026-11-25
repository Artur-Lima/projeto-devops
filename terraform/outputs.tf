output "ip_publico" {
  description = "IP público da VM"
  value       = oci_core_instance.vm.public_ip
}

output "ssh" {
  description = "Comando para acessar a VM"
  value       = "ssh -i ${var.ssh_private_key_path} ${local.usuario_ssh}@${oci_core_instance.vm.public_ip}"
}

output "proximo_passo" {
  description = "Comando para preparar a VM e implantar a aplicação"
  value       = "cd ../ansible && ansible-playbook -i inventory.terraform.ini site.yml"
}

output "url_aplicacao" {
  description = "Endereço da aplicação depois do Ansible"
  value       = "http://${oci_core_instance.vm.public_ip}/"
}
