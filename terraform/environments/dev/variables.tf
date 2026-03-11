variable "project_id" {
    description = "GCP project ID"
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