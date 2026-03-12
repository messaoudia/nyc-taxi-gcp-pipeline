import os
import json
import logging
import requests
from google.cloud import pubsub_v1, storage, parametermanager_v1, secretmanager_v1

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def run():
    """
    Cloud Run Job - Ingest NYC Taxi data from a public URL
    and upload it sreamingly to a GCS bucket + publish a message to Pub/Sub with the file information

    Environment variables expected:
    - CLOUD_RUN_TASK_INDEX: The index of the Cloud Run task: given by GCP
    - GOOGLE_CLOUD_PROJECT: The GCP project ID
    - BUCKET_NAME: The name of the GCS bucket where the data will be uploaded
    - TOPIC_NAME: The name of the Pub/Sub topic where the message will be published
    - NYC_DATA_URI: The base URI of the NYC taxi data files
    - ENVIRONMENT: The environment (dev, staging,prod)
    """

    # Environment variables for the function
    cloud_run_task_index = int(os.getenv("CLOUD_RUN_TASK_INDEX", "0"))
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    bucket_name = os.getenv("BUCKET_NAME")
    topic_name = os.getenv("TOPIC_NAME")
    nyc_data_secret = os.getenv("NYC_DATA_SECRET")
    environment = os.getenv("ENVIRONMENT")

    storage_client = storage.Client()
    secret_manager_client = secretmanager_v1.SecretManagerServiceClient()

    secret_version = secret_manager_client.access_secret_version(
        request=secretmanager_v1.AccessSecretVersionRequest(name=nyc_data_secret)
    )

    secret_version_payload = secret_version.payload.data.decode("UTF-8")
    nyc_data_uri = json.loads(secret_version_payload).get("nyc_data_uri")

    parameter_manager_client = parametermanager_v1.ParameterManagerClient()
    parameter_name = f"projects/{project_id}/locations/global/parameters/nyc-taxi-gcp-pipeline-{environment}-parameter/versions/latest"

    nyc_files = json.loads(
        parameter_manager_client.render_parameter_version(
            request=parametermanager_v1.RenderParameterVersionRequest(
                name=parameter_name
            )
        ).payload.data
    ).get("nyc_files")

    if nyc_files is None:
        raise ValueError(
            "The 'nyc_files' parameter is missing in the Parameter Manager."
        )

    try:
        nyc_data_parquet = nyc_files[cloud_run_task_index]
    except IndexError as e:
        error_message = (
            f"""
                Invalid number of CLOUD_RUN_TASK_INDEX, there is not enough nyc_files: {cloud_run_task_index}
                Error: {str(e)}
            """,
        )
        logger.error(error_message)
        raise e

    complete_nyc_data_uri = f"{nyc_data_uri}{nyc_data_parquet}"

    blob = storage_client.bucket(bucket_name).blob(f"raw/{nyc_data_parquet}")
    if blob.exists():
        logger.info(
            f"The file raw/{nyc_data_parquet} already exists in the bucket {bucket_name}. Skipping download and upload."
        )
        return

    with requests.get(complete_nyc_data_uri, stream=True, timeout=600) as response:
        response.raise_for_status()

        blob.upload_from_file(
            response.raw,
            content_type="application/octet-stream",
        )

    publisher = pubsub_v1.PublisherClient()
    topic_full_path = f"projects/{project_id}/topics/{topic_name}"
    data = json.dumps(
        {
            "bucket": bucket_name,
            "file_name": f"raw/{nyc_data_parquet}",
        }
    ).encode("utf-8")

    future = publisher.publish(topic_full_path, data=data)

    future.result()  # Wait for the publish call to complete

    logger.info(
        f"Publishing message to Pub/Sub topic: {topic_name} with data: {complete_nyc_data_uri}"
    )


if __name__ == "__main__":
    run()
