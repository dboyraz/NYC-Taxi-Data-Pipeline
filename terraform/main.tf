terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Service account for pipeline access
resource "google_service_account" "pipeline_sa" {
  account_id   = "nyc-taxi-pipeline"
  display_name = "NYC Taxi Pipeline Service Account"
}

resource "google_project_iam_member" "sa_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

resource "google_project_iam_member" "sa_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

resource "google_project_iam_member" "sa_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.pipeline_sa.email}"
}

# GCS bucket for data lake (raw parquet files)
resource "google_storage_bucket" "data_lake" {
  name          = var.gcs_bucket_name
  location      = var.location
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# BigQuery dataset
resource "google_bigquery_dataset" "nyc_taxi" {
  dataset_id = var.bq_dataset_name
  location   = var.location

  delete_contents_on_destroy = true
}

# BigQuery partitioned + clustered table (optimized for queries)
resource "google_bigquery_table" "yellow_taxi" {
  dataset_id          = google_bigquery_dataset.nyc_taxi.dataset_id
  table_id            = "yellow_taxi"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "tpep_pickup_datetime"
  }

  clustering = ["payment_type", "PULocationID"]

  schema = file("${path.module}/schemas/yellow_taxi.json")

  depends_on = [google_bigquery_dataset.nyc_taxi]
}
