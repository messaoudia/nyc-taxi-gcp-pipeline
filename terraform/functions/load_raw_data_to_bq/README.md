# Cloud Function Job

## To test it out
```python
if __name__ == "__main__":
    class CloudEvent:
        def __init__(self, data):
            self.data = data

    cloud_event = CloudEvent(
        {
            "bucket": "nyctaxi-data-dev",
            "name": "raw/tripdata/yellow_tripdata_2025-01.parquet",
        }
    )
    load(cloud_event)
```