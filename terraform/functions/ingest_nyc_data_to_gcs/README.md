# Cloud Run Jobs
docker buildx build --platform linux/amd64 -t europe-west9-docker.pkg.dev/nyc-taxi-gcp-pipeline/nyc-taxi-gcp-pipeline-dev-repository/nyc-taxi-ingester-dev:latest .
docker push europe-west9-docker.pkg.dev/nyc-taxi-gcp-pipeline/nyc-taxi-gcp-pipeline-dev-repository/nyc-taxi-ingester-dev:latest
# local test
docker build -t nyc-taxi-downloader .
docker run --rm -it --env-file .env --entrypoint bash nyc-taxi-downloader
