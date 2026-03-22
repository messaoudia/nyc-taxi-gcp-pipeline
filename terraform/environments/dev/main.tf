terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "7.23.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region = var.region
}

data "google_project" "project" {}

data "google_storage_project_service_account" "gcs_account" {}
