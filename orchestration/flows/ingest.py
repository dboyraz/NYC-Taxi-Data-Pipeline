"""
NYC Yellow Taxi data pipeline.

Flow: Download parquet → Upload to GCS → Load into BigQuery partitioned table.
"""

import os
from pathlib import Path

import requests
from google.cloud import bigquery, storage
from prefect import flow, task

GCP_PROJECT = os.getenv("GCP_PROJECT_ID", "nyc-taxi-491513")
GCS_BUCKET = os.getenv("GCS_BUCKET_NAME", "nyc-taxi-491513-data-lake")
BQ_DATASET = os.getenv("BQ_DATASET", "nyc_taxi")
BQ_TABLE = f"{GCP_PROJECT}.{BQ_DATASET}.yellow_taxi"

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"


@task(log_prints=True, retries=2)
def download_parquet(year: int, month: int) -> Path:
    """Download a single month of yellow taxi data as parquet."""
    filename = f"yellow_tripdata_{year}-{month:02d}.parquet"
    filepath = DATA_DIR / filename

    if filepath.exists():
        print(f"Already downloaded: {filename}")
        return filepath

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    url = f"{BASE_URL}/{filename}"
    print(f"Downloading {url}")

    response = requests.get(url, timeout=300)
    response.raise_for_status()

    filepath.write_bytes(response.content)
    print(f"Saved {filename} ({filepath.stat().st_size / 1e6:.1f} MB)")
    return filepath


@task(log_prints=True, retries=2)
def upload_to_gcs(filepath: Path) -> str:
    """Upload parquet file to GCS data lake."""
    client = storage.Client(project=GCP_PROJECT)
    bucket = client.bucket(GCS_BUCKET)
    blob_name = f"raw/yellow_taxi/{filepath.name}"
    blob = bucket.blob(blob_name)

    if blob.exists():
        print(f"Already in GCS: {blob_name}")
        return f"gs://{GCS_BUCKET}/{blob_name}"

    print(f"Uploading {filepath.name} to gs://{GCS_BUCKET}/{blob_name}")
    blob.upload_from_filename(str(filepath))
    print(f"Upload complete: {blob_name}")
    return f"gs://{GCS_BUCKET}/{blob_name}"


@task(log_prints=True)
def load_gcs_to_bigquery(gcs_uri: str) -> int:
    """Load parquet from GCS into BigQuery partitioned table."""
    client = bigquery.Client(project=GCP_PROJECT)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="tpep_pickup_datetime",
        ),
        clustering_fields=["payment_type", "PULocationID"],
    )

    print(f"Loading {gcs_uri} into {BQ_TABLE}")
    load_job = client.load_table_from_uri(gcs_uri, BQ_TABLE, job_config=job_config)
    load_job.result()

    table = client.get_table(BQ_TABLE)
    print(f"Table {BQ_TABLE} now has {table.num_rows} rows")
    return table.num_rows


@flow(name="nyc-yellow-taxi-ingest", log_prints=True)
def ingest_flow(year: int = 2024, months: list[int] | None = None):
    """
    End-to-end pipeline: download → GCS → BigQuery.

    Args:
        year: Year of data to ingest.
        months: List of months (1-12). Defaults to [1, 2] for a manageable dataset.
    """
    if months is None:
        months = [1, 2]

    print(f"Starting ingestion for {year}, months={months}")

    # Download all months in parallel
    download_futures = [download_parquet.submit(year, month) for month in months]

    # Upload to GCS as downloads complete, then load to BigQuery
    for future in download_futures:
        filepath = future.result()
        gcs_uri = upload_to_gcs(filepath)
        load_gcs_to_bigquery(gcs_uri)

    print("Pipeline complete!")


if __name__ == "__main__":
    ingest_flow()
