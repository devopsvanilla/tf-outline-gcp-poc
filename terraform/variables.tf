variable "project_id" {
  description = "ID do projeto GCP onde os recursos serão provisionados."
  type        = string
}

variable "region" {
  description = "Região GCP para os recursos (us-central1, us-east1 ou us-west1 para o Free Tier)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona GCP da VM."
  type        = string
  default     = "us-central1-a"
}

variable "credentials_file" {
  description = "Caminho local para chave JSON de credencial administrativa (opcional; se omitido/null, usa a autenticação ativa da estação via gcloud ADC)."
  type        = string
  default     = null
}

variable "bucket_name_prefix" {
  description = "Prefixo do bucket Cloud Storage para os arquivos do Outline (um sufixo aleatório será adicionado)."
  type        = string
  default     = "outline-files"
}

variable "instance_name" {
  description = "Nome da instância Compute Engine."
  type        = string
  default     = "outline-vm"
}

variable "static_ip_name" {
  description = "Nome personalizado para o recurso de IP público estático (se null, usa <instance_name>-ip)."
  type        = string
  default     = null
}

variable "machine_type" {
  description = "Tipo de máquina da VM (e2-micro é elegível para o Free Tier da GCP)."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_size" {
  description = "Tamanho do disco de boot em GB (até 30 GB de pd-standard é gratuito no Always Free Tier)."
  type        = number
  default     = 30
}

variable "boot_disk_type" {
  description = "Tipo do disco de boot (pd-standard para Free Tier)."
  type        = string
  default     = "pd-standard"
}

variable "network" {
  description = "VPC onde a VM será criada."
  type        = string
  default     = "default"
}

variable "ssh_source_ranges" {
  description = "CIDRs permitidos para acesso SSH (porta 22)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "web_source_ranges" {
  description = "CIDRs permitidos para acesso Web (portas 80, 443 e 3000)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_user" {
  description = "Usuário SSH utilizado pelo Ansible (com a política requireOsLogin da GCP, deve ser o nome de usuário POSIX do seu perfil OS Login, ex: devopsvanillaofficial_gmail_com)."
  type        = string
  default     = "devopsvanillaofficial_gmail_com"
}

variable "ssh_public_key_file" {
  description = "Caminho local para o arquivo de chave pública SSH (.pub) a ser injetada no metadata da VM (opcional; se null, usa OS Login do gcloud)."
  type        = string
  default     = null
}

variable "domain_name" {
  description = "FQDN que será utilizado para acessar o Outline (ex: wiki.meudominio.com). Se nulo, utiliza o IP público."
  type        = string
  default     = null
}

# ==============================================================================
# Variáveis para a VM do diagrams.net (draw.io)
# ==============================================================================
variable "enable_drawio_vm" {
  description = "Habilita o provisionamento da VM dedicada para o diagrams.net (draw.io)."
  type        = bool
  default     = true
}

variable "drawio_instance_name" {
  description = "Nome da instância Compute Engine para o diagrams.net (draw.io)."
  type        = string
  default     = "drawio-vm"
}

variable "drawio_static_ip_name" {
  description = "Nome personalizado para o recurso de IP público estático do diagrams.net (se null, usa <drawio_instance_name>-ip)."
  type        = string
  default     = null
}

variable "drawio_machine_type" {
  description = "Tipo de máquina para a VM do diagrams.net (e2-micro)."
  type        = string
  default     = "e2-micro"
}

variable "drawio_boot_disk_size" {
  description = "Tamanho do disco de boot em GB para a VM do diagrams.net."
  type        = number
  default     = 20
}

variable "drawio_boot_disk_type" {
  description = "Tipo do disco de boot para a VM do diagrams.net (pd-standard)."
  type        = string
  default     = "pd-standard"
}

variable "drawio_domain_name" {
  description = "FQDN que será utilizado para acessar o diagrams.net (ex: drawio-cabr-poc.devopsvanilla.com.br)."
  type        = string
  default     = null
}

