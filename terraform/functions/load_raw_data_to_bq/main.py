import os
import logging
import functions_framework
from google.cloud import bigquery

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cloud run function triggered by EventArchive when a new file is uploaded to the GCS bucket

client = bigquery.Client()


@functions_framework.cloud_event
def load(cloud_event):
    """Cloud Run Function triggered by EventArchive when a new file is uploaded to the GCS bucket
    AKA google.cloud.storage.object.v1.finalized event.
    When a file is ingested to GCS this function is triggered and it loads the data to BigQuery

    Args:
        cloud_event (dict): Cloud event data object
    """
    bq_trip_table = os.environ.get("BQ_TRIP_TABLE")

    if not bq_trip_table:
        raise ValueError("BQ_TRIP_TABLE environment variable is not set")

    data = cloud_event.data
    bucket_name = data["bucket"]
    file_name = data["name"]
    logger.info(
        f"Received cloud event: New file uploaded to GCS: {bucket_name}/{file_name}"
    )

    if not file_name.startswith("raw/tripdata") or not file_name.endswith(".parquet"):
        logger.info(
            f"File {file_name} is not a parquet file or does not contain 'tripdata' in path. Skipping."
        )
        return

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,  # append because we want to keep the existing data and add new data to it
    )

    uri = f"gs://{bucket_name}/{file_name}"

    load_job = client.load_table_from_uri(
        source_uris=[uri],
        destination=bigquery.TableReference.from_string(bq_trip_table),
        job_config=job_config,
    )

    load_job.result()

    logger.info(
        f"Loaded successfully {load_job.output_rows} rows from {uri} to BigQuery table {bq_trip_table}"
    )
