output "instance_external_ip" {
  description = "IP público estático da VM do Outline."
  value       = google_compute_address.outline_ip.address
}

output "instance_static_ip_name" {
  description = "Nome do recurso do endereço IP público estático na GCP."
  value       = google_compute_address.outline_ip.name
}

output "bucket_name" {
  description = "Nome do bucket Cloud Storage usado para arquivos do Outline."
  value       = google_storage_bucket.outline_files.name
}

output "bucket_region" {
  description = "Região do bucket Cloud Storage."
  value       = google_storage_bucket.outline_files.location
}

output "outline_service_account_email" {
  description = "Service account criada para acessar o bucket."
  value       = google_service_account.outline.email
}

output "outline_storage_access_key" {
  description = "Access ID da chave HMAC para interoperabilidade S3 com o Cloud Storage."
  value       = google_storage_hmac_key.outline_key.access_id
}

output "outline_storage_secret_key" {
  description = "Secret da chave HMAC para interoperabilidade S3 com o Cloud Storage."
  value       = google_storage_hmac_key.outline_key.secret
  sensitive   = true
}

output "outline_fqdn" {
  description = "FQDN configurado para o Outline (ou IP público se não informado)."
  value       = var.domain_name != null && var.domain_name != "" ? var.domain_name : google_compute_address.outline_ip.address
}

output "ansible_inventory_command" {
  description = "Comando rápido para gerar o inventário do Ansible (Outline e draw.io)."
  value       = var.enable_drawio_vm ? "printf \"[outline]\\noutline-vm ansible_host=%s ansible_user=%s\\n\\n[drawio]\\ndrawio-vm ansible_host=%s ansible_user=%s\\n\" \"${google_compute_address.outline_ip.address}\" \"${var.ssh_user != null && var.ssh_user != "" ? var.ssh_user : "debian"}\" \"${google_compute_address.drawio_ip[0].address}\" \"${var.ssh_user != null && var.ssh_user != "" ? var.ssh_user : "debian"}\" > ../ansible/inventory.ini" : "printf \"[outline]\\noutline-vm ansible_host=%s ansible_user=%s\\n\" \"${google_compute_address.outline_ip.address}\" \"${var.ssh_user != null && var.ssh_user != "" ? var.ssh_user : "debian"}\" > ../ansible/inventory.ini"
}

output "drawio_instance_external_ip" {
  description = "IP público estático da VM do diagrams.net (draw.io)."
  value       = var.enable_drawio_vm ? google_compute_address.drawio_ip[0].address : null
}

output "drawio_fqdn" {
  description = "FQDN configurado para o diagrams.net (ou IP público se não informado)."
  value       = var.enable_drawio_vm ? (var.drawio_domain_name != null && var.drawio_domain_name != "" ? var.drawio_domain_name : google_compute_address.drawio_ip[0].address) : null
}

