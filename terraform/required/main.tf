terraform {
    required_version = ">= 1.5"
    required_providers {
        google = {
            source = "hashicorp/google"
            version = "6.8.0"
        }
    }
}

provider "google" {
    project = var.project_id
    region = var.region
}

resource "google_storage_bucket" "terraform_tfstate" {
    name = "${var.project_id}-terraform-state"
    location = var.region
    storage_class = "STANDARD"
    uniform_bucket_level_access = true

    versioning {
        enabled = true
    }

    lifecycle {
        prevent_destroy = true
    }
}