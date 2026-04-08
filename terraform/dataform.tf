# gitbub repository for dataform
# resource "google_dataform_repository" "dataform_repo" {
#   project     = var.project_id
#   location    = var.region
#   repository_id = "${var.app_name}-dataform-repo-${var.environment}"
#   display_name = "${var.app_name} Dataform Repository ${var.environment}"
#   description  = "Dataform repository for ${var.app_name} in ${var.environment} environment"
# 
#   git_remote_settings {
#     url = var.repository_url
#     default_branch = var.repository_default_branch
#     authentication_token
# }