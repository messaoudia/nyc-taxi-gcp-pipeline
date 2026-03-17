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

resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudrun" {
  service            = "run.googleapis.com"  # déjà présent ✅
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Run API
resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Enable Eventarc API
resource "google_project_service" "eventarc" {
  service            = "eventarc.googleapis.com"
  disable_on_destroy = false
}

# Enable Pub/Sub API
resource "google_project_service" "pubsub" {
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# Enable Scheduler API
resource "google_project_service" "scheduler" {
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable Parameter Manager API
resource "google_project_service" "parametermanager" {
  service            = "parametermanager.googleapis.com"
  disable_on_destroy = false
}

# Enable Artifact Registry API
resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Enable BigQuery API
resource "google_project_service" "bigquery" {
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Functions API
resource "google_project_service" "cloudfunctions" {
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Build API
resource "google_project_service" "cloudbuild" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Logging API
resource "google_project_service" "cloudlogging" {
  service            = "logging.googleapis.com"
  disable_on_destroy = false
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
 name         = "raw/staticdata/taxi_zone_lookup.csv"
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
  display_name = "Service Account for Cloud Run Job"
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

resource "google_service_account" "scheduler_sa" {
  account_id   = "${var.app_name}-scheduler-sa-${var.environment}"
  display_name = "Service Account for Cloud Scheduler"
}

resource "google_project_iam_member" "scheduler_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

resource "google_cloud_scheduler_job" "ingest_nyc_data" {
  name     = "${var.app_name}-ingest-scheduler-${var.environment}"
  schedule = "0 0 1 * *"  # 1er de chaque mois
  region   = "europe-west3" # europe-west9 not supported by Cloud Scheduler as of now

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.ingest_nyc_data_to_gcs.name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
    }
  }

  depends_on = [
    google_project_service.scheduler,
    google_cloud_run_v2_job.ingest_nyc_data_to_gcs,
    google_project_iam_member.scheduler_run_invoker,
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

  deletion_protection = false # set to "true" in production
}

resource "google_bigquery_table" "taxi_zone_lookup_table" {
  dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
  table_id   = "taxi_zone_lookup"
  schema     = file("${path.module}/schemas/taxi_zone_lookup.json")

  depends_on = [
    google_bigquery_dataset.raw_dataset,
  ]

  deletion_protection = false # set to "true" in production
}

resource "google_bigquery_job" "load_taxi_zone_lookup" {
  job_id = "${var.app_name}-load-taxi-zone-lookup-${var.environment}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  location = var.location

  load {
    source_uris = ["gs://${module.gcs_data.bucket.name}/raw/staticdata/taxi_zone_lookup.csv"]

    destination_table {
      project_id = var.project_id
      dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
      table_id   = google_bigquery_table.taxi_zone_lookup_table.table_id
    }

    source_format = "CSV"
    skip_leading_rows = 1
    autodetect = false
    write_disposition = "WRITE_TRUNCATE"
  }

  depends_on = [
    google_bigquery_table.taxi_zone_lookup_table,
    google_storage_bucket_object.default,
  ]
}

data "archive_file" "functions_zip" {
  type        = "zip"
  source_dir  = "../../functions/load_raw_data_to_bq"
  output_path = "/tmp/load_raw_data_to_bq_function.zip"
}

resource "google_storage_bucket_object" "load_raw_data_to_bq_function_source" {
  name   = "function-load-to-bq-${data.archive_file.functions_zip.output_md5}.zip"
  bucket = module.gcs_functions.bucket.name
  source = data.archive_file.functions_zip.output_path
}

resource "google_service_account" "cloud_run_job_function_load_bq_account" {
  account_id   = "${var.app_name}-load-bq-sa-${var.environment}"
  display_name = "Service Account for Cloud Run Function"
}

resource "google_storage_bucket_iam_member" "gcf_source_access" {
  bucket = "gcf-v2-sources-${data.google_project.project.number}-${var.location}"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"
}

resource "google_storage_bucket_iam_member" "gcs_data_access" {
  bucket = module.gcs_data.bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"
}

resource "google_project_iam_custom_role" "bq_loader" {
  role_id = "bqLoader"
  title   = "BQ Loader"
  permissions = [
    "bigquery.tables.create",
    "bigquery.tables.updateData",
    "bigquery.tables.get",
    "bigquery.jobs.create",
  ]
}

resource "google_project_iam_member" "cloud_run_function_bq_loader" {
  project = var.project_id
  role    = google_project_iam_custom_role.bq_loader.name
  member  = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"

  depends_on = [
    google_project_iam_custom_role.bq_loader,
    google_bigquery_dataset.raw_dataset,
    google_service_account.cloud_run_job_function_load_bq_account,
  ]
}

resource "google_project_iam_member" "cloud_run_function_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"

  depends_on = [
    google_bigquery_dataset.raw_dataset,
    google_service_account.cloud_run_job_function_load_bq_account,
  ]
}

# roles/logging.logWriter
resource "google_project_iam_member" "cloud_run_function_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"

  depends_on = [
    google_service_account.cloud_run_job_function_load_bq_account,
  ]
}

# logging.logEntries.list
resource "google_project_iam_member" "cloud_run_function_log_reader" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"

  depends_on = [
    google_service_account.cloud_run_job_function_load_bq_account,
  ]
}

resource "google_project_iam_member" "cloud_run_function_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloud_run_job_function_load_bq_account.email}"
}

resource "google_cloudfunctions2_function" "load_raw_data_to_bigquery" {
  name = "${var.app_name}-load-to-bq-${var.environment}"
  description = "Cloud Function to ingest data to BigQuery"
  location = var.location

  build_config {
    runtime = "python313"
    entry_point = "load"
    service_account = "projects/${var.project_id}/serviceAccounts/${google_service_account.cloud_run_job_function_load_bq_account.email}"

    # For the source code, we will use a Cloud Storage bucket as the source, but in production, it's better to use versioning tool like
    # Github, Gitlab or if keeping all in GCP : Cloud Source Repositories
    source {
      storage_source {
        bucket = module.gcs_functions.bucket.name
        object = google_storage_bucket_object.load_raw_data_to_bq_function_source.name
      }
    }
  }

  service_config {
    available_memory   = "256M"

    service_account_email = google_service_account.cloud_run_job_function_load_bq_account.email

    environment_variables = {
      BQ_TRIP_TABLE = "${var.project_id}.${google_bigquery_dataset.raw_dataset.dataset_id}.${google_bigquery_table.raw_yellow_tripdata_table.table_id}"
    }

    all_traffic_on_latest_revision = true # newer versions of function v2 will receive all traffic
    # ingress_settings               = "ALLOW_INTERNAL_ONLY"
    ingress_settings = "ALLOW_ALL" # for dev only
  }

  depends_on = [
    google_storage_bucket_object.load_raw_data_to_bq_function_source,
    google_service_account.cloud_run_job_function_load_bq_account,
    google_project_iam_member.cloud_run_function_bq_loader,
    google_project_iam_member.cloud_run_function_bq_job_user,
    google_bigquery_table.raw_yellow_tripdata_table,
    google_project_iam_member.cloud_run_function_log_writer,
    google_project_iam_member.cloud_run_function_log_reader,
    google_project_iam_member.cloud_run_function_artifact_registry,
  ]
}

# Event arc

# Create a dedicated service account
resource "google_service_account" "eventarc" {
  account_id   = "eventarc-trigger-sa-${var.environment}"
  display_name = "Eventarc Trigger Service Account"
}

# Grant permission to receive Eventarc events
resource "google_project_iam_member" "eventreceiver" {
  project = data.google_project.project.id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

# Grant permission to invoke Cloud Run services
resource "google_project_iam_member" "runinvoker" {
  project = data.google_project.project.id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

resource "google_project_iam_member" "pubsubpublisher" {
  project = data.google_project.project.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Create an Eventarc trigger, routing Cloud Storage events to Cloud Run
resource "google_eventarc_trigger" "eventarc_trigger" {
  name     = "trigger-storage-cloudrun-tf"
  location = google_cloudfunctions2_function.load_raw_data_to_bigquery.location

  # Capture objects changed in the bucket
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = module.gcs_data.bucket.name
  }

  # Send events to Cloud Run
  destination {
    cloud_run_service {
      service = google_cloudfunctions2_function.load_raw_data_to_bigquery.name
      region  = google_cloudfunctions2_function.load_raw_data_to_bigquery.location
    }
  }

  service_account = google_service_account.eventarc.email
  depends_on = [
    google_project_service.eventarc,
    google_project_iam_member.pubsubpublisher,
    google_cloudfunctions2_function.load_raw_data_to_bigquery,
  ]
}