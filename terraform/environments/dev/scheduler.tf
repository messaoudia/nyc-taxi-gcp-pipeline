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