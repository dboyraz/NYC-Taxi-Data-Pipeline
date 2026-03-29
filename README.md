# NYC Yellow Taxi Data Pipeline

## Problem Statement

New York City's yellow taxi system generates millions of trip records monthly. Understanding trip patterns — how passengers pay, daily demand fluctuations, and seasonal trends — helps city planners, taxi companies, and policy makers make informed decisions about fleet allocation, pricing, and infrastructure.

This project builds an end-to-end data pipeline that ingests NYC Yellow Taxi trip data, processes it through a cloud-based data warehouse, and surfaces insights in a dashboard with two key visualizations:
1. **Trip distribution by payment type** — shows the dominance of credit card vs cash payments
2. **Daily trip volume over time** — reveals weekday/weekend patterns and demand trends

## Architecture

```
NYC TLC Website          GCS (Data Lake)          BigQuery (DWH)          Looker Studio
  [Parquet] ──download──▶ [Raw Parquet] ──load──▶ [yellow_taxi]  ──read──▶ [Dashboard]
                                                       │
                                                   dbt transforms
                                                       │
                                                  ┌────┴────┐
                                                  ▼         ▼
                                          [mart_daily  [mart_trips_by
                                           _trips]      _payment]
```

**Pipeline orchestration:** Prefect (batch mode, multi-step DAG)

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Cloud | Google Cloud Platform (GCP) |
| Infrastructure as Code | Terraform |
| Data Lake | Google Cloud Storage (GCS) |
| Data Warehouse | BigQuery |
| Orchestration | Prefect |
| Transformations | dbt (dbt-bigquery) |
| Dashboard | Looker Studio |
| Package Management | uv |

## Data Warehouse Design

The `yellow_taxi` table is:
- **Partitioned by** `tpep_pickup_datetime` (DAY) — most dashboard queries filter by date range, so partitioning eliminates scanning irrelevant days
- **Clustered by** `payment_type`, `PULocationID` — the payment type distribution tile filters/groups by payment type, and location-based queries benefit from clustering on pickup location

## dbt Models

| Model | Type | Description |
|-------|------|-------------|
| `stg_yellow_taxi` | View | Cleans raw data: renames columns to snake_case, maps payment type codes to names, filters out invalid trips (negative fares, zero distance, dates outside 2026) |
| `mart_trips_by_payment` | Table | Aggregated trip counts and averages grouped by payment type — powers dashboard tile 1 |
| `mart_daily_trips` | Table | Daily trip counts, revenue, and averages — powers dashboard tile 2 |

## Prerequisites

- [Google Cloud Platform](https://cloud.google.com/) account with billing enabled (free trial works)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [uv](https://docs.astral.sh/uv/getting-started/installation/) (Python package manager)

## Setup & Reproduction

### 1. Clone and install dependencies

```bash
git clone <repo-url>
cd "DE Project"
uv sync
```

### 2. Configure GCP project

```bash
gcloud auth login
gcloud config set project <YOUR_PROJECT_ID>
```

### 3. Provision infrastructure with Terraform

```bash
cd terraform
terraform init
terraform apply -var="project_id=<YOUR_PROJECT_ID>" -auto-approve
cd ..
```

This creates:
- GCS bucket for the data lake
- BigQuery dataset and partitioned + clustered table
- Service account (`nyc-taxi-pipeline`) with BigQuery and GCS IAM roles

### 4. Set up authentication (service account impersonation)

```bash
# Enable the required API
gcloud services enable iamcredentials.googleapis.com

# Grant your user permission to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  nyc-taxi-pipeline@<YOUR_PROJECT_ID>.iam.gserviceaccount.com \
  --member="user:<YOUR_EMAIL>" \
  --role="roles/iam.serviceAccountTokenCreator"

# Set up Application Default Credentials with impersonation
gcloud auth application-default login \
  --impersonate-service-account=nyc-taxi-pipeline@<YOUR_PROJECT_ID>.iam.gserviceaccount.com
```

This avoids managing service account key files — credentials are short-lived and auto-refreshed.

### 5. Set environment variables

```bash
export GCP_PROJECT_ID=<YOUR_PROJECT_ID>
export GCS_BUCKET_NAME=<YOUR_PROJECT_ID>-data-lake
export BQ_DATASET=nyc_taxi
```

### 6. Run the data pipeline

```bash
uv run python orchestration/flows/ingest.py
```

This executes a 3-step Prefect flow:
1. Downloads Jan & Feb 2026 yellow taxi parquet files from NYC TLC
2. Uploads them to GCS data lake
3. Loads data into the BigQuery partitioned table

### 7. Run dbt transformations

```bash
cd dbt
uv run dbt run --profiles-dir .
uv run dbt test --profiles-dir .
cd ..
```

### 8. Dashboard

The Looker Studio dashboard is available at: [Dashboard Link](https://lookerstudio.google.com/reporting/c70fac6c-06ab-4adb-9321-f5eb455d0dc5)

To recreate it:
1. Go to [lookerstudio.google.com](https://lookerstudio.google.com)
2. Create a new report
3. Connect to BigQuery → your project → `nyc_taxi`
4. Add `mart_trips_by_payment` → create a bar chart (payment_type_name vs trip_count)
5. Add `mart_daily_trips` → create a time series (trip_date vs trip_count)

## Project Structure

```
terraform/              # IaC — GCS bucket, BigQuery dataset & tables
  main.tf
  variables.tf
  outputs.tf
  schemas/
    yellow_taxi.json    # BigQuery table schema
orchestration/
  flows/
    ingest.py           # Prefect flow: download → GCS → BigQuery
dbt/
  dbt_project.yml
  profiles.yml
  models/
    staging/
      stg_yellow_taxi.sql
    mart/
      mart_daily_trips.sql
      mart_trips_by_payment.sql
data/                   # Downloaded parquet files (gitignored)
```
