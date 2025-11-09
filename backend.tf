terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_YOUR_BUCKET_NAME" # Replace with your GCS bucket name
    prefix = "terraform/state"               # Path within the bucket to store state
    
    # Optional: Enable encryption at rest
    # encryption_key = "projects/PROJECT_ID/locations/global/keyRings/KEYRING_NAME/cryptoKeys/KEY_NAME"
  }
}
