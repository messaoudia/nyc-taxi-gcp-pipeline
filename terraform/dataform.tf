resource "google_dataform_repository" "repository" {
  provider = google-beta
  project = var.project_id
  region = var.region
  name = "${var.app_name}-repository-${var.environment}"

  service_account = google_service_account.dataform_sa.email

  # npmrc_environment_variables_secret_version = google_secret_manager_secret_version.github_secrets_version.id

  labels = {
    environment = var.environment
  }

  git_remote_settings {
    url                                 = var.repository_url
    default_branch                      = var.repository_default_branch
    authentication_token_secret_version = google_secret_manager_secret_version.github_secrets_version.id
  }

  workspace_compilation_overrides {
    default_database = var.dataform_default_database
  }

  depends_on = [
    google_secret_manager_secret_version.github_secrets_version
  ]
}


resource "google_dataform_repository_release_config" "release_config" {
  provider = google-beta

  project    = google_dataform_repository.repository.project
  region     = google_dataform_repository.repository.region
  repository = google_dataform_repository.repository.name

  name          = "${var.environment}-release"
  git_commitish = var.repository_default_branch
  cron_schedule = "0 7 * * *"
  time_zone     = "Europe/Paris"

  code_compilation_config {
    default_database = var.dataform_default_database
    default_schema   = "nyctaxi_staging_dataform_dev" #TODO: make it dynamic
    default_location = "europe-west9" #TODO: make it dynamic

    vars = {
      app_name = "nyctaxi" #TODO: make it dynamic
      env = var.environment
    }
  }

  depends_on = [google_dataform_repository.repository]
}

resource "google_dataform_repository_workflow_config" "workflow_finance" {
  provider = google-beta

  project        = google_dataform_repository.repository.project
  region         = google_dataform_repository.repository.region
  repository     = google_dataform_repository.repository.name
  name           = "${var.environment}-workflow-finance"
  release_config = google_dataform_repository_release_config.release_config.id

  invocation_config {
    included_tags                            = ["finance"]
    transitive_dependencies_included         = true
    transitive_dependents_included           = true
    fully_refresh_incremental_tables_enabled = false
    service_account                          = google_service_account.dataform_sa.email
  }

  depends_on = [google_dataform_repository_release_config.release_config]
}

resource "google_dataform_repository_workflow_config" "workflow_geo" {
  provider = google-beta

  project        = google_dataform_repository.repository.project
  region         = google_dataform_repository.repository.region
  repository     = google_dataform_repository.repository.name
  name           = "${var.environment}-workflow-geo"
  release_config = google_dataform_repository_release_config.release_config.id

  invocation_config {
    included_tags                            = ["geo"]
    transitive_dependencies_included         = true
    transitive_dependents_included           = true
    fully_refresh_incremental_tables_enabled = false
    service_account                          = google_service_account.dataform_sa.email
  }

  depends_on = [google_dataform_repository_release_config.release_config]

}

resource "google_dataform_repository_workflow_config" "workflow_marts" {
  provider = google-beta

  project        = google_dataform_repository.repository.project
  region         = google_dataform_repository.repository.region
  repository     = google_dataform_repository.repository.name
  name           = "${var.environment}-workflow-marts"
  release_config = google_dataform_repository_release_config.release_config.id

  invocation_config {
    included_tags                            = ["marts"]
    transitive_dependencies_included         = true
    transitive_dependents_included           = true
    fully_refresh_incremental_tables_enabled = false
    service_account                          = google_service_account.dataform_sa.email
  }

  depends_on = [google_dataform_repository_release_config.release_config]
}