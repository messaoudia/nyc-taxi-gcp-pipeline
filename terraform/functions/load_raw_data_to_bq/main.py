import logging
import functions_framework
from google.cloud import storage, bigquery

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cloud run function triggered by EventArchive when a new file is uploaded to the GCS bucket


@functions_framework.cloud_event
def load(cloud_event):
    """Cloud Run Function triggered by EventArchive when a new file is uploaded to the GCS bucket
    When a file is ingested to GCS this function is triggered and it loads the data to BigQuery

    Args:
        cloud_event (dict): The cloud event data
    """
    data = cloud_event.data
    logger.info(f"Received cloud event: {data}")
    bucket_name = data["bucket"]
    file_name = data["name"]
    logger.info(f"New file uploaded to GCS: {bucket_name}/{file_name}")

    # Initialize BigQuery client
    bq_client = bigquery.Client()
    # file name format is "raw/yellow_tripdata_2025-01.parquet"
    partition_id = file_name.replace("parquet", "").split("_")[-1]
    dataset_id = "nyc_taxi"
    table_id = f"yellow_tripdata_{partition_id}"
