output "data_lake_bucket" {
  value       = google_storage_bucket.data_lake.name
  description = "GCS data lake bucket name"
}

output "bigquery_dataset" {
  value       = google_bigquery_dataset.nyc_taxi.dataset_id
  description = "BigQuery dataset ID"
}

output "pipeline_service_account" {
  value       = google_service_account.pipeline_sa.email
  description = "Service account email for pipeline"
}
