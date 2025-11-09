#!/bin/bash

# Secure CI/CD Infrastructure Setup Script for GCP
# This script sets up the necessary infrastructure for Terraform with Cloud Build
# Prerequisites: gcloud CLI installed and authenticated with appropriate permissions

set -e  # Exit on any error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration variables - UPDATE THESE
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${GCP_REGION:-us-central1}"
BUCKET_NAME="${TERRAFORM_STATE_BUCKET:-}"
SECRET_NAME="terraform-db-password"
SECRET_VALUE="${DB_PASSWORD:-}"

# Validate inputs
if [ -z "$PROJECT_ID" ]; then
    print_error "GCP_PROJECT_ID environment variable is not set"
    echo "Usage: GCP_PROJECT_ID=your-project-id GCP_REGION=us-central1 TERRAFORM_STATE_BUCKET=your-bucket-name DB_PASSWORD=your-password $0"
    exit 1
fi

if [ -z "$BUCKET_NAME" ]; then
    print_error "TERRAFORM_STATE_BUCKET environment variable is not set"
    echo "Usage: GCP_PROJECT_ID=your-project-id GCP_REGION=us-central1 TERRAFORM_STATE_BUCKET=your-bucket-name DB_PASSWORD=your-password $0"
    exit 1
fi

if [ -z "$SECRET_VALUE" ]; then
    print_warn "DB_PASSWORD not set, will prompt for secret value"
    read -sp "Enter the database password for Secret Manager: " SECRET_VALUE
    echo ""
fi

print_info "Starting setup for project: $PROJECT_ID"
print_info "Region: $REGION"
print_info "Bucket name: $BUCKET_NAME"

# Set the active project
print_info "Setting active GCP project..."
gcloud config set project "$PROJECT_ID"

# Enable required APIs
print_info "Enabling required GCP APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    cloudresourcemanager.googleapis.com \
    storage.googleapis.com \
    secretmanager.googleapis.com \
    iam.googleapis.com \
    --project="$PROJECT_ID"

print_info "Waiting for APIs to be fully enabled..."
sleep 10

# Create GCS bucket for Terraform state
print_info "Creating GCS bucket for Terraform state..."
if gsutil ls -b "gs://${BUCKET_NAME}" 2>/dev/null; then
    print_warn "Bucket gs://${BUCKET_NAME} already exists, skipping creation"
else
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${BUCKET_NAME}"
    print_info "Bucket created successfully"
fi

# Enable versioning on the bucket for state file protection
print_info "Enabling versioning on the bucket..."
gsutil versioning set on "gs://${BUCKET_NAME}"

# Enable uniform bucket-level access for better security
print_info "Enabling uniform bucket-level access..."
gsutil uniformbucketlevelaccess set on "gs://${BUCKET_NAME}"

# Create or update the secret in Secret Manager
print_info "Creating secret in Secret Manager..."
if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" 2>/dev/null; then
    print_warn "Secret $SECRET_NAME already exists, adding new version"
    echo -n "$SECRET_VALUE" | gcloud secrets versions add "$SECRET_NAME" \
        --project="$PROJECT_ID" \
        --data-file=-
else
    echo -n "$SECRET_VALUE" | gcloud secrets create "$SECRET_NAME" \
        --project="$PROJECT_ID" \
        --replication-policy="automatic" \
        --data-file=-
    print_info "Secret created successfully"
fi

# Get Cloud Build service account
print_info "Getting Cloud Build service account..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
print_info "Cloud Build service account: $CLOUD_BUILD_SA"

# Grant Cloud Build service account access to the secret
print_info "Granting Cloud Build access to Secret Manager..."
gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:${CLOUD_BUILD_SA}" \
    --role="roles/secretmanager.secretAccessor"

# Grant Cloud Build service account access to the GCS bucket
print_info "Granting Cloud Build access to GCS bucket..."
gsutil iam ch "serviceAccount:${CLOUD_BUILD_SA}:roles/storage.objectAdmin" "gs://${BUCKET_NAME}"

# Grant additional permissions for Cloud Build to manage resources
print_info "Granting Cloud Build additional IAM permissions..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CLOUD_BUILD_SA}" \
    --role="roles/editor" \
    --condition=None

# Optional: Create a custom service account for Cloud Build (more secure)
print_info "Creating custom service account for Cloud Build (optional)..."
CUSTOM_SA_NAME="cloud-build-terraform"
CUSTOM_SA_EMAIL="${CUSTOM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$CUSTOM_SA_EMAIL" --project="$PROJECT_ID" 2>/dev/null; then
    print_warn "Service account $CUSTOM_SA_EMAIL already exists"
else
    gcloud iam service-accounts create "$CUSTOM_SA_NAME" \
        --project="$PROJECT_ID" \
        --description="Service account for Cloud Build Terraform deployments" \
        --display-name="Cloud Build Terraform SA"
    print_info "Custom service account created: $CUSTOM_SA_EMAIL"
fi

# Grant permissions to the custom service account
print_info "Granting permissions to custom service account..."
gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:${CUSTOM_SA_EMAIL}" \
    --role="roles/secretmanager.secretAccessor"

gsutil iam ch "serviceAccount:${CUSTOM_SA_EMAIL}:roles/storage.objectAdmin" "gs://${BUCKET_NAME}"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CUSTOM_SA_EMAIL}" \
    --role="roles/editor" \
    --condition=None

# Summary
print_info "=========================================="
print_info "Setup completed successfully!"
print_info "=========================================="
echo ""
print_info "Next steps:"
echo "  1. Update backend.tf with bucket name: $BUCKET_NAME"
echo "  2. Configure Cloud Build trigger in your repository"
echo "  3. (Optional) Update cloudbuild.yaml to use custom SA: $CUSTOM_SA_EMAIL"
echo ""
print_info "Resources created:"
echo "  - GCS Bucket: gs://${BUCKET_NAME}"
echo "  - Secret: projects/${PROJECT_ID}/secrets/${SECRET_NAME}"
echo "  - Service Account: ${CUSTOM_SA_EMAIL}"
echo ""
print_warn "Security reminders:"
echo "  - Keep your state bucket secure and private"
echo "  - Regularly rotate secrets in Secret Manager"
echo "  - Review and minimize IAM permissions as needed"
echo "  - Enable audit logging for compliance"
