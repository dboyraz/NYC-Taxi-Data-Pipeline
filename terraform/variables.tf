variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "nyc-taxi-491513"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "GCP location for BigQuery dataset"
  type        = string
  default     = "US"
}

variable "gcs_bucket_name" {
  description = "GCS bucket for the data lake"
  type        = string
  default     = "nyc-taxi-491513-data-lake"
}

variable "bq_dataset_name" {
  description = "BigQuery dataset name"
  type        = string
  default     = "nyc_taxi"
}
