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
  bucket_name = "${var.project_id}-${var.environment}-${var.bucket_name}"
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
}

module "gcs_functions" {
  source     = "../../modules/gcs"
  bucket_name = "${var.project_id}-${var.environment}-functions"
  location    = var.location
  storage_class = "STANDARD"
}

resource "google_service_account" "cloud_run_job_service_account" {
  account_id   = "${var.project_id}-function-sa"
  display_name = "Service Account for Cloud Functions"
}

resource "google_storage_bucket_iam_member" "cloud_run_job_bucket_access" {
  bucket = module.gcs_data.bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"
}

resource "google_parameter_manager_iam_member" "function_parameter_access" {
  parameter = google_parameter_manager_parameter.default.name
  role      = "roles/parametermanager.parameterAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"
}

resource "google_service_account_iam_member" "cloud_run_job_user" {
  service_account_id = google_service_account.cloud_run_job_service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_run_job_service_account.email}"
}

module "pubsub" {
  source     = "../../modules/pubsub"
  topic_name = "${var.project_id}-${var.environment}-${var.topic_name}"
}

resource "google_parameter_manager_parameter" "default" {
  parameter_id = "${var.project_id}-${var.environment}-parameter"
  format = "JSON"
}

resource "google_parameter_manager_parameter_version" "default" {
  parameter = google_parameter_manager_parameter.default.name
  parameter_version_id = "${var.project_id}-${var.environment}-parameter-version-latest"
  parameter_data = jsonencode({
      "nyc_files": [
      "yellow_tripdata_2025-01.parquet",
      "yellow_tripdata_2025-02.parquet"
    ]
  })
}

# TODO transform to cloud run + retry policy + monitoring + alerting
resource "google_cloudfunctions2_function" "simulate_events_function" {
  name = "${var.project_id}-simulate-events-function-${var.topic_name}" # TODO make the function name to variable
  description = "Cloud Function to simulate NYC taxi trip events"
  location = var.location

  build_config {
    runtime = "python313"
    entry_point = "trigger"
    source {
      storage_source {
        bucket = module.gcs_functions.bucket.name
        object = google_storage_bucket_object.simulate_function_source.name
      }
    }
  }

  service_config {
    available_memory   = "256M"
    timeout_seconds    = 60

    environment_variables = {
      GOOGLE_CLOUD_PROJECT = var.project_id
      BUCKET_NAME = module.gcs_data.bucket.name
      TOPIC_NAME = module.pubsub.topic.name
      NYC_DATA_URI = "https://d37ci6vzurychx.cloudfront.net/trip-data/"
      # https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2025-01.parquet
    }

    all_traffic_on_latest_revision = true # newer versions of function will receive all traffic
    # ingress_settings               = "ALLOW_INTERNAL_ONLY"
    ingress_settings = "ALLOW_ALL" # for dev only
  }
}