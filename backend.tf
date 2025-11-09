terraform {
  backend "gcs" {
    bucket = "tfstate-real-slim-shady-fedramp-high" # Replace with your GCS bucket name
    prefix = "terraform/state"               # Path within the bucket to store state
    
    # Optional: Enable encryption at rest
    # encryption_key = "projects/PROJECT_ID/locations/global/keyRings/KEYRING_NAME/cryptoKeys/KEY_NAME"
  }
}