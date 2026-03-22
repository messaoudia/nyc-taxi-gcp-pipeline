resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id = "${var.app_name}_raw_${var.environment}"
  location   = var.location
}

resource "google_bigquery_table" "raw_yellow_tripdata_table" {
  dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
  table_id   = "yellow_tripdata"
  schema     = file("${path.module}/schemas/raw_yellow_tripdata.json")

  labels = {
    created_by = "dbt"
  }

  time_partitioning {
    type = "DAY"
    field = "tpep_pickup_datetime"
  }

  clustering = ["PULocationID", "DOLocationID"]

  depends_on = [
    google_bigquery_dataset.raw_dataset,
  ]

  deletion_protection = false # set to "true" in production
}

resource "google_bigquery_table" "taxi_zone_lookup_table" {
  dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
  table_id   = "taxi_zone_lookup"
  schema     = file("${path.module}/schemas/taxi_zone_lookup.json")

  labels = {
    created_by = "dbt"
  }

  depends_on = [
    google_bigquery_dataset.raw_dataset,
  ]

  deletion_protection = false # set to "true" in production
}

resource "google_bigquery_job" "load_taxi_zone_lookup" {
  job_id = "${var.app_name}-load-taxi-zone-lookup-${var.environment}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  location = var.location

  load {
    source_uris = ["gs://${module.gcs_data.bucket.name}/raw/staticdata/taxi_zone_lookup.csv"]

    destination_table {
      project_id = var.project_id
      dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
      table_id   = google_bigquery_table.taxi_zone_lookup_table.table_id
    }

    source_format = "CSV"
    skip_leading_rows = 1
    autodetect = false
    write_disposition = "WRITE_TRUNCATE"
  }

  depends_on = [
    google_bigquery_table.taxi_zone_lookup_table,
    google_storage_bucket_object.default,
  ]
}