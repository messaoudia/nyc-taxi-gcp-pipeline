FROM python:3.13-slim
WORKDIR /ingest_nyc_data_to_gcs
COPY requirements.txt .
COPY main.py .
RUN useradd -m ingest_user && chown -R ingest_user:ingest_user /ingest_nyc_data_to_gcs
USER ingest_user

RUN pip install --no-cache-dir -r requirements.txt --user

ENTRYPOINT [ "python", "main.py" ]