variable "project_id" {
    description = "GCP project ID"
    type        = string
}

variable "app_name" {
    description = "Application name for resource naming"
    type        = string
}

variable "location" {
    description = "GCP location name"
    type        = string
}

variable "region" {
    description = "GCP region name"
    default     = "eu-west9" # Paris
}

variable "environment" {
    description = "target environment"
    type        = string
    default     = "dev"

    validation {
        condition = contains(["dev", "staging", "prod"], var.environment)
        error_message = "Ensure that your environment is either dev/staging/prod"
    }
}

variable "bucket_name" {
    description = "Bucket where NYC data will be processed"
    type        = string
}

variable "topic_name" {
    description = "Pub/Sub topic name for raw trip data"
    type        = string
}

variable "nyc_data_uri" {
    description = "URI for NYC taxi trip data"
    type        = string
}

variable "impersonation_users" {
    description = "List of users that can impersonate the Cloud Run service account"
    type        = list(string)
}

variable "repository_url" {
    description = "URL of the GitHub repository for Dataform"
    type        = string
}

variable "repository_default_branch" {
    description = "Default branch of the GitHub repository for Dataform"
    type        = string
}

variable "dataform_default_database" {
    description = "Default database for Dataform compilation"
    type        = string
}

variable "github_pat_token" {
    description = "GitHub Personal Access Token for Dataform repository access"
    type        = string
    sensitive   = true
}