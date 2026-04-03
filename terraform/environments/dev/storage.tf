module "gcs_data" {
  source     = "../../modules/gcs"
  bucket_name = "${var.app_name}-${var.bucket_name}-${var.environment}"
  location    = var.location
  storage_class = "STANDARD"
  versioning = false
  lifecycle_rules = [
    {
      action = {
        type = "Delete"
      }
      condition = {
        age = 30
      }
    }
  ]
  force_destroy = true # set to "false" in production
}

resource "google_storage_bucket_object" "static_taxi_zone_lookup" {
 name         = "raw/staticdata/taxi_zone_lookup.csv"
 source       = "${path.module}/../../data/taxi_zone_lookup.csv"
 content_type = "text/csv"
 bucket       = module.gcs_data.bucket.name
}

resource "google_storage_bucket_object" "static_location_state" {
 name         = "raw/staticdata/location_state.csv"
 source       = "${path.module}/../../data/location_state.csv"
 content_type = "text/csv"
 bucket       = module.gcs_data.bucket.name
}

resource "google_storage_bucket_object" "static_us_states" {
 name         = "raw/staticdata/us_states.csv"
 source       = "${path.module}/../../data/us_states.csv"
 content_type = "text/csv"
 bucket       = module.gcs_data.bucket.name
}

module "gcs_functions" {
  source     = "../../modules/gcs"
  bucket_name = "${var.app_name}-functions-${var.environment}"
  location    = var.location
  storage_class = "STANDARD"
  force_destroy = true # set to "false" in production
}

resource "google_storage_bucket_object" "load_raw_data_to_bq_function_source" {
  name   = "function-load-to-bq-${data.archive_file.functions_zip.output_md5}.zip"
  bucket = module.gcs_functions.bucket.name
  source = data.archive_file.functions_zip.output_path
}