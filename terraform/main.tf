provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null
}

resource "random_id" "bucket_suffix" {
  byte_length = 3
}

locals {
  bucket_name = lower(format("%s-%s", var.bucket_name_prefix, random_id.bucket_suffix.hex))
  network_tag = "outline-server"
}

resource "google_storage_bucket" "outline_files" {
  name                        = local.bucket_name
  location                    = var.region
  project                     = var.project_id
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
}

resource "google_service_account" "outline" {
  account_id   = "outline-storage"
  display_name = "Outline storage access"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "outline_object_admin" {
  bucket = google_storage_bucket.outline_files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.outline.email}"
}

resource "google_compute_firewall" "ssh_ingress" {
  name    = "${var.instance_name}-ssh"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [local.network_tag]
}

resource "google_compute_firewall" "outline_ingress" {
  name    = "${var.instance_name}-outline"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = var.outline_source_ranges
  target_tags   = [local.network_tag]
}

resource "google_compute_instance" "outline_vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.network_tag]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.network

    access_config {
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}
