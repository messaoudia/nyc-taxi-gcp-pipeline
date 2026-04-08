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

# This is not best practice to store an URI or non-sensitive data in Secret Manager
# But for the demo purpose, we will store the NYC data URI in Secret Manager to demonstrate how to use secrets in Cloud Run jobs
resource "google_secret_manager_secret_version" "secrets_version" {
  secret      = google_secret_manager_secret.secrets.name
  secret_data = jsonencode({
    "nyc_data_uri": var.nyc_data_uri,
    "github_token": var.github_token,
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