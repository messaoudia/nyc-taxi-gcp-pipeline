output "state_bucket_name" {
  description = "Bucket name for Terraform state"
  value       = google_storage_bucket.terraform_tfstate.name
}

output "state_bucket_url" {
  description = "URL of the GCS bucket"
  value       = google_storage_bucket.terraform_tfstate.url
}