locals {
  docker_image_uri = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repository.repository_id}/${var.app_name}-ingester-${var.environment}:latest"
}