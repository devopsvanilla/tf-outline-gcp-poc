output "instance_external_ip" {
  description = "IP público da VM do Outline."
  value       = google_compute_instance.outline_vm.network_interface[0].access_config[0].nat_ip
}

output "bucket_name" {
  description = "Nome do bucket Cloud Storage usado para arquivos do Outline."
  value       = google_storage_bucket.outline_files.name
}

output "outline_service_account_email" {
  description = "Service account criada para acessar o bucket."
  value       = google_service_account.outline.email
}
