resource "google_artifact_registry_repository" "repository" {
  provider = google
  repository_id = "${var.app_name}-repository-${var.environment}"
  location = var.location
  format = "DOCKER"
}