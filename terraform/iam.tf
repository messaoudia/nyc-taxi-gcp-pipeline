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

resource "google_service_account" "scheduler_sa" {
  account_id   = "${var.app_name}-scheduler-sa-${var.environment}"
  display_name = "Service Account for Cloud Scheduler"
}

resource "google_project_iam_member" "scheduler_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
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
  role_id = "bqLoader_${var.environment}"
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

resource "google_service_account" "dataform_sa" {
  account_id   = "${var.app_name}-dataform-sa-${var.environment}"
  display_name = "Service Account for Cloud Dataform"
}

resource "google_project_iam_member" "dataform_bq_access_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataform_sa.email}"

  depends_on = [
    google_service_account.dataform_sa,
  ]
}

resource "google_project_iam_member" "dataform_bq_access_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dataform_sa.email}"

  depends_on = [
    google_service_account.dataform_sa,
  ]
}

resource "google_secret_manager_secret_iam_member" "dataform_github_access" {
  project = var.project_id
  secret_id = google_secret_manager_secret.github.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [
    google_secret_manager_secret.github,
    google_service_account.dataform_sa,
  ]
}

resource "google_secret_manager_secret_iam_member" "dataform_sa_github_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.github.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.dataform_sa.email}"

  depends_on = [
    google_secret_manager_secret.github,
    google_service_account.dataform_sa,
  ]
}

resource "google_service_account_iam_member" "dataform_sa_self_token_creator" {
  service_account_id = google_service_account.dataform_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.dataform_sa.email}"

  depends_on = [google_service_account.dataform_sa]
}

resource "google_project_iam_member" "dataform_sa_dataform_editor" {
  project = var.project_id
  role    = "roles/dataform.editor"
  member  = "serviceAccount:${google_service_account.dataform_sa.email}"

  depends_on = [google_service_account.dataform_sa]
}


# Allow Dataform system SA to impersonate our dataform SA
resource "google_service_account_iam_member" "dataform_system_sa_token_creator" {
  service_account_id = google_service_account.dataform_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [google_service_account.dataform_sa, google_secret_manager_secret_iam_member.dataform_github_access]
}

resource "google_service_account_iam_member" "dataform_system_sa_account_user" {
  service_account_id = google_service_account.dataform_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"

  depends_on = [google_service_account.dataform_sa]
}
