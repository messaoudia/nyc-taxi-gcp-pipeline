module "pubsub" {
  source     = "../../modules/pubsub"
  topic_name = "${var.app_name}-ingestion-${var.environment}"
}

# Create an Eventarc trigger, routing Cloud Storage events to Cloud Run
resource "google_eventarc_trigger" "eventarc_trigger" {
  name     = "trigger-storage-cloudrun-tf-${var.environment}"
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