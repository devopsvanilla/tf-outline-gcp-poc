variable "project_id" {
  description = "ID do projeto GCP."
  type        = string
}

variable "region" {
  description = "Região GCP para os recursos."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona GCP da VM."
  type        = string
  default     = "us-central1-a"
}

variable "credentials_file" {
  description = "Caminho local para a credencial administrativa usada pelo provider Google."
  type        = string
  default     = ""
}

variable "bucket_name_prefix" {
  description = "Prefixo do bucket Cloud Storage. Um sufixo aleatório será adicionado."
  type        = string
  default     = "outline-poc"
}

variable "instance_name" {
  description = "Nome da instância Compute Engine."
  type        = string
  default     = "outline-vm"
}

variable "machine_type" {
  description = "Tipo de máquina da VM."
  type        = string
  default     = "e2-micro"
}

variable "network" {
  description = "VPC onde a VM será criada."
  type        = string
  default     = "default"
}

variable "ssh_source_ranges" {
  description = "CIDRs permitidos para SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "outline_source_ranges" {
  description = "CIDRs permitidos para acesso ao Outline."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
