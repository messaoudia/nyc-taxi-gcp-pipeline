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
        vpc_access{
          network_interfaces {
            network = google_compute_network.vpc.id
            subnetwork = google_compute_subnetwork.subnet.id
          }
          egress = "ALL_TRAFFIC"
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