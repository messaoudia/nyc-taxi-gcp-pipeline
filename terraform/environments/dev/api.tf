resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudrun" {
  service            = "run.googleapis.com"
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

resource "google_project_service" "vpcaccess" {
  service            = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dataform" {
  service            = "dataform.googleapis.com"
  disable_on_destroy = false
}