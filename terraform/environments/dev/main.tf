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

module "gcs_data" {
  source     = "../../modules/gcs"
  bucket_name = "${var.app_name}-${var.bucket_name}-${var.environment}"
  location    = var.location
  storage_class = "STANDARD"
  versioning = false
  lifecycle_rules = [
    {
      action = {
        type = "Delete"
      }
      condition = {
        age = 30
      }
    }
  ]
  force_destroy = true # set to "false" in production
}

resource "google_storage_bucket_object" "default" {
 name         = "taxi_zone_lookup.csv"
 source       = "${path.module}/../../data/taxi_zone_lookup.csv"
 content_type = "text/csv"
 bucket       = module.gcs_data.bucket.name
}

module "gcs_functions" {
  source     = "../../modules/gcs"
  bucket_name = "${var.app_name}-functions-${var.environment}"
  location    = var.location
  storage_class = "STANDARD"
  force_destroy = true # set to "false" in production
}

resource "google_service_account" "cloud_run_job_service_account" {
  account_id   = "${var.app_name}-ingest-sa-${var.environment}"
  display_name = "Service Account for Cloud Functions"
}

resource "google_storage_bucket_iam_member" "cloud_run_job_bucket_access_creator" {
  bucket = module.gcs_data.bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"
  depends_on = [
    module.gcs_data,
    google_service_account.cloud_run_job_service_account,
  ]
}

resource "google_storage_bucket_iam_member" "cloud_run_job_bucket_access_viewer" {
  bucket = module.gcs_data.bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"
  depends_on = [
    module.gcs_data,
    google_service_account.cloud_run_job_service_account,
  ]
}

resource "google_secret_manager_secret_iam_member" "cloud_run_job_secret_access" {
  secret_id = google_secret_manager_secret.secrets.secret_id
  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"
  depends_on = [
    google_secret_manager_secret.secrets,
    google_service_account.cloud_run_job_service_account,
  ]
}

resource "google_project_iam_member" "cloud_run_job_parameter_access" {
  project = var.project_id
  role    = "roles/parametermanager.parameterAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"

  depends_on = [
    google_parameter_manager_parameter.default,
    google_service_account.cloud_run_job_service_account,
  ]
}


resource "google_service_account_iam_member" "impersonation" {
  for_each = toset(var.impersonation_users)

  service_account_id = google_service_account.cloud_run_job_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${each.value}"

  depends_on = [
    google_service_account.cloud_run_job_service_account,
  ]
}

resource "google_service_account_iam_member" "cloud_run_job_user" {
  service_account_id = google_service_account.cloud_run_job_service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"

  depends_on = [
    google_service_account.cloud_run_job_service_account,
  ]
}

module "pubsub" {
  source     = "../../modules/pubsub"
  topic_name = "${var.app_name}-ingestion-${var.environment}"
}

resource "google_secret_manager_secret" "secrets" {
  project = var.project_id
  secret_id = "${var.app_name}-secrets-${var.environment}"
  replication {
    user_managed {
      replicas {
        location = "europe-west1"
      }
    }
  }
}

# This is not best practice to store non-sensitive data in Secret Manager
# But for the demo purpose, we will store the NYC data URI in Secret Manager to demonstrate how to use secrets in Cloud Run jobs
resource "google_secret_manager_secret_version" "secrets_version" {
  secret      = google_secret_manager_secret.secrets.name
  secret_data = jsonencode({
    "nyc_data_uri": var.nyc_data_uri
  })
}

resource "google_parameter_manager_parameter" "default" {
  parameter_id = "${var.app_name}-parameter-${var.environment}"
  format = "JSON"
}

resource "google_parameter_manager_parameter_version" "default" {
  parameter = google_parameter_manager_parameter.default.name
  parameter_version_id = "${var.app_name}-parameter-manager-${var.environment}"
  parameter_data = jsonencode({
      "nyc_files": [
      "yellow_tripdata_2025-01.parquet",
      "yellow_tripdata_2025-02.parquet",
      "yellow_tripdata_2025-03.parquet",
      "yellow_tripdata_2025-04.parquet",
    ]
  })
}

resource "google_artifact_registry_repository" "repository" {
  provider = google
  repository_id = "${var.app_name}-repository-${var.environment}"
  location = var.location
  format = "DOCKER"
}

locals {
  docker_image_uri = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repository.repository_id}/${var.app_name}-ingester-${var.environment}:latest"
}

# TODO transform to cloud run + retry policy + monitoring + alerting
resource "google_cloud_run_v2_job" "ingest_nyc_data_to_gcs" {
  name = "${var.app_name}-ingest-nyc-data-to-gcs-job-${var.environment}"
  location = var.location

  deletion_protection = false # set to "true" in production check https://docs.cloud.google.com/run/docs/create-jobs?hl=fr#terraform

  template {
    task_count = 4
    template {
        service_account = google_service_account.cloud_run_job_service_account.email
        containers {
        image = local.docker_image_uri
        env {
          name = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
        env {
          name = "BUCKET_NAME"
          value = module.gcs_data.bucket.name
        }
        env {
          name = "TOPIC_NAME"
          value = module.pubsub.topic.name
        }
        env {
          name = "ENVIRONMENT"
          value = var.environment
        }
        env {
          name = "NYC_DATA_SECRET"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.secrets.secret_id
              version = "latest"
            }
          }
        }
        env {
          name = "PARAMETER_NAME"
          value = google_parameter_manager_parameter_version.default.name
        }
      }
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.cloud_run_job_bucket_access_creator,
    google_storage_bucket_iam_member.cloud_run_job_bucket_access_viewer,
    google_service_account_iam_member.cloud_run_job_user,
    google_secret_manager_secret_version.secrets_version,
    google_parameter_manager_parameter_version.default,
    google_artifact_registry_repository.repository,
  ]

}

resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id = "${var.app_name}_raw_${var.environment}"
  location   = var.location
}

resource "google_bigquery_table" "raw_yellow_tripdata_table" {
  dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
  table_id   = "yellow_tripdata"
  schema     = file("${path.module}/schemas/raw_yellow_tripdata.json")

  time_partitioning {
    type = "DAY"
    field = "tpep_pickup_datetime"
  }

  clustering = ["PULocationID", "DOLocationID"]

  depends_on = [
    google_bigquery_dataset.raw_dataset,
  ]
}

resource "google_bigquery_table" "taxi_zone_lookup_table" {
  dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
  table_id   = "taxi_zone_lookup"
  schema     = file("${path.module}/schemas/taxi_zone_lookup.json")

  depends_on = [
    google_bigquery_dataset.raw_dataset,
  ]
}