data "archive_file" "functions_zip" {
  type        = "zip"
  source_dir  = "../../functions/load_raw_data_to_bq"
  output_path = "/tmp/load_raw_data_to_bq_function.zip"
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
    # ingress_settings = "ALLOW_ALL" # for dev only
    ingress_settings = "ALLOW_INTERNAL_ONLY"

    vpc_connector = google_vpc_access_connector.connector.id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
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