output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.non_compliant_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.non_compliant_cluster.endpoint
  sensitive   = true
}

output "llama_public_ip" {
  description = "Public IP of llama.cpp service (NON-COMPLIANT)"
  value       = "Run: kubectl get svc llama-server -n llama-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "bucket_name" {
  description = "GCS bucket for models (NON-COMPLIANT: public, no CMEK)"
  value       = google_storage_bucket.model_storage.name
}

output "sql_instance_name" {
  description = "Cloud SQL instance name (NON-COMPLIANT: public IP)"
  value       = google_sql_database_instance.demo_db.name
}

output "sql_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.demo_db.connection_name
}

output "sql_public_ip" {
  description = "Cloud SQL public IP (NON-COMPLIANT)"
  value       = google_sql_database_instance.demo_db.public_ip_address
}
