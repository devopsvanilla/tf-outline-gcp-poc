provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
  credentials = var.credentials_file != null && var.credentials_file != "" ? file(var.credentials_file) : null
}

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

locals {
  bucket_name           = lower(format("%s-%s", var.bucket_name_prefix, random_id.bucket_suffix.hex))
  network_tag           = "outline-server"
  static_ip_name        = var.static_ip_name != null && var.static_ip_name != "" ? var.static_ip_name : "${var.instance_name}-ip"
  drawio_network_tag    = "drawio-server"
  drawio_static_ip_name = var.drawio_static_ip_name != null && var.drawio_static_ip_name != "" ? var.drawio_static_ip_name : "${var.drawio_instance_name}-ip"
}

# Bucket Cloud Storage para arquivos do Outline com CORS habilitado para uploads diretos via browser
resource "google_storage_bucket" "outline_files" {
  name                        = local.bucket_name
  location                    = var.region
  project                     = var.project_id
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# Service account dedicada para o Outline acessar o Cloud Storage
resource "google_service_account" "outline" {
  account_id   = "outline-storage"
  display_name = "Outline storage access"
  project      = var.project_id
}

# Permissão de administração de objetos no bucket para a Service Account
resource "google_storage_bucket_iam_member" "outline_object_admin" {
  bucket = google_storage_bucket.outline_files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.outline.email}"
}

# Chave HMAC para interoperabilidade S3 com o Google Cloud Storage
resource "google_storage_hmac_key" "outline_key" {
  service_account_email = google_service_account.outline.email
  project               = var.project_id
}

# Regra de Firewall para acesso SSH
resource "google_compute_firewall" "ssh_ingress" {
  name    = "${var.instance_name}-ssh"
  network = var.network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [local.network_tag]
}

# Regra de Firewall para portas Web (HTTP 80, HTTPS 443, Outline 3000) e ping ICMP
resource "google_compute_firewall" "web_ingress" {
  name    = "${var.instance_name}-web"
  network = var.network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3000"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.web_source_ranges
  target_tags   = [local.network_tag]
}

# IP público estático reservado para a VM
resource "google_compute_address" "outline_ip" {
  name        = local.static_ip_name
  region      = var.region
  project     = var.project_id
  description = "IP publico estatico reservado para a VM do Outline"
}

# Instância Compute Engine e2-micro (GCP Always Free Tier)
resource "google_compute_instance" "outline_vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id
  tags         = [local.network_tag]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network = var.network

    access_config {
      nat_ip = google_compute_address.outline_ip.address
    }
  }

  service_account {
    email  = google_service_account.outline.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  lifecycle {
    ignore_changes = [metadata["startup-script"]]
  }
}

# ==============================================================================
# Recursos da VM diagrams.net (draw.io)
# ==============================================================================

# IP público estático reservado para a VM do diagrams.net
resource "google_compute_address" "drawio_ip" {
  count       = var.enable_drawio_vm ? 1 : 0
  name        = local.drawio_static_ip_name
  region      = var.region
  project     = var.project_id
  description = "IP publico estatico reservado para a VM do diagrams.net (draw.io)"
}

# Regra de Firewall para acesso SSH à VM do diagrams.net
resource "google_compute_firewall" "drawio_ssh_ingress" {
  count   = var.enable_drawio_vm ? 1 : 0
  name    = "${var.drawio_instance_name}-ssh"
  network = var.network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [local.drawio_network_tag]
}

# Regra de Firewall para portas Web (HTTP 80, HTTPS 443) e ping ICMP na VM do diagrams.net
resource "google_compute_firewall" "drawio_web_ingress" {
  count   = var.enable_drawio_vm ? 1 : 0
  name    = "${var.drawio_instance_name}-web"
  network = var.network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.web_source_ranges
  target_tags   = [local.drawio_network_tag]
}

# Instância Compute Engine e2-micro para o diagrams.net (draw.io)
resource "google_compute_instance" "drawio_vm" {
  count        = var.enable_drawio_vm ? 1 : 0
  name         = var.drawio_instance_name
  machine_type = var.drawio_machine_type
  zone         = var.zone
  project      = var.project_id
  tags         = [local.drawio_network_tag]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = var.drawio_boot_disk_size
      type  = var.drawio_boot_disk_type
    }
  }

  network_interface {
    network = var.network

    access_config {
      nat_ip = google_compute_address.drawio_ip[0].address
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

