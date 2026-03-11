import os
import flask
import requests
from google.cloud import pubsub_v1, storage


def run(request: flask.Request):
    """HTTP Cloud Function to simulate events by sending message to a Pub/Sub topic.

    Args:
        request (flask.Request): request data which will contain the end of the URI of the data to send to Pub/Sub
    """
    print(f"Received event: {request.args}")
    # Environment variables for the function
    cloud_run_task_index = os.getenv("CLOUD_RUN_TASK_INDEX")
    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    bucket_name = os.getenv("BUCKET_NAME")
    topic_name = os.getenv("TOPIC_NAME")
    nyc_data_uri = os.getenv("NYC_DATA_URI")

    #
    nyc_data_parquet = request.get_json().get("nyc_data_parquet")

    if nyc_data_parquet is None:
        return "Missing 'nyc_data_parquet' query parameter", 400
    # request.get(nyc_data_parquet)

    complete_nyc_data_uri = f"{nyc_data_uri}{nyc_data_parquet}"
    response = requests.get(complete_nyc_data_uri)

    if response.status_code != 200:
        return f"Failed to access the data at {complete_nyc_data_uri}", 400

    data = response.content
    storage_client = storage.Client()

    storage_client.bucket(bucket_name).blob(
        f"raw/{nyc_data_parquet}"
    ).upload_from_string(data)

    publisher = pubsub_v1.PublisherClient()
    topic_full_path = f"projects/{project_id}/topics/{topic_name}"

    future = publisher.publish(
        topic_full_path, b"My first message ... :D", nyc_data_uri=complete_nyc_data_uri
    )

    future.result()  # Wait for the publish call to complete

    print(
        f"Publishing message to Pub/Sub topic: {topic_name} with data: {complete_nyc_data_uri}"
    )

    return (
        f"Message published to Pub/Sub topic: {topic_name} with data: {complete_nyc_data_uri}",
        200,
    )
