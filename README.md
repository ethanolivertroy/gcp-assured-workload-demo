# GCP Assured Workload Demo - Secure CI/CD Pipeline

This repository contains a secure CI/CD pipeline setup for Google Cloud Platform (GCP) using Terraform and Cloud Build.

## Overview

This project provides a production-ready CI/CD pipeline that implements security best practices for managing infrastructure as code on GCP.

## Components

### 1. `.gitignore`
Ensures sensitive Terraform files (state, variables, secrets) are never committed to the repository.

### 2. `backend.tf`
Configures Terraform to use Google Cloud Storage (GCS) as a remote backend for state management.

**Configuration:**
- Update the `bucket` name with your GCS bucket name after running the setup script
- State files are stored with versioning enabled for rollback capability
- Supports optional encryption at rest using Cloud KMS

### 3. `cloudbuild.yaml`
Defines the Cloud Build pipeline with the following steps:
1. **Retrieve Secret**: Fetches the database password from Secret Manager
2. **Terraform Init**: Initializes Terraform with the remote backend
3. **Terraform Validate**: Validates Terraform configuration syntax
4. **Terraform Plan**: Creates an execution plan
5. **Terraform Apply**: Applies the infrastructure changes (typically on main branch)

**Security Features:**
- Secrets managed through Secret Manager (not in code)
- Automatic secret injection into build steps
- Cloud logging for audit trails
- Machine type optimized for CI/CD workloads

### 4. `setup-infrastructure.sh`
A bash script that automates the initial infrastructure setup:
- Creates a GCS bucket for Terraform state with versioning and uniform access
- Creates a secret in Secret Manager (terraform-db-password)
- Enables required GCP APIs
- Configures IAM permissions for Cloud Build service accounts
- Creates an optional custom service account for enhanced security

## Getting Started

### Prerequisites

- GCP account with appropriate permissions
- `gcloud` CLI installed and authenticated
- A GCP project created

### Step 1: Run the Infrastructure Setup Script

```bash
# Set required environment variables
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"  # Optional, defaults to us-central1
export TERRAFORM_STATE_BUCKET="your-unique-bucket-name"
export DB_PASSWORD="your-secure-password"

# Run the setup script
./setup-infrastructure.sh
```

### Step 2: Update Configuration Files

After running the setup script:

1. Update `backend.tf` with your bucket name:
   ```hcl
   bucket = "your-unique-bucket-name"
   ```

2. (Optional) Update `cloudbuild.yaml` to use the custom service account created by the setup script

### Step 3: Configure Cloud Build Trigger

1. Go to [Cloud Build Triggers](https://console.cloud.google.com/cloud-build/triggers) in the GCP Console
2. Click "Create Trigger"
3. Connect your GitHub repository
4. Configure trigger settings:
   - **Event**: Push to a branch
   - **Branch**: `^main$` (or your default branch)
   - **Build configuration**: Cloud Build configuration file (yaml or json)
   - **Location**: `/cloudbuild.yaml`
5. Save the trigger

### Step 4: Push Your Terraform Code

Add your Terraform configuration files to the repository and push to trigger the CI/CD pipeline.

## Security Best Practices

✅ **State Files**: Never committed (protected by .gitignore)  
✅ **Secrets**: Managed in Secret Manager, not in code  
✅ **IAM**: Principle of least privilege with custom service accounts  
✅ **Versioning**: State bucket versioning enabled for rollback  
✅ **Encryption**: GCS encryption at rest (default) with optional KMS  
✅ **Audit Logging**: Cloud Build logging enabled  

## Usage Examples

### Manual Terraform Operations

If you need to run Terraform locally:

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan -var="db_password=${DB_PASSWORD}"

# Apply changes
terraform apply -var="db_password=${DB_PASSWORD}"
```

### Checking Pipeline Status

```bash
# List recent builds
gcloud builds list --limit=5

# View build logs
gcloud builds log <BUILD_ID>
```

## Troubleshooting

### Permission Denied Errors
Ensure the Cloud Build service account has the necessary IAM roles:
- Secret Manager Secret Accessor
- Storage Object Admin (on state bucket)
- Editor role on project (or specific resource permissions)

### State Lock Issues
If Terraform state is locked, you may need to manually remove the lock:
```bash
# List state locks
terraform force-unlock <LOCK_ID>
```

### Secret Not Found
Verify the secret exists and has the correct name:
```bash
gcloud secrets list --project=your-project-id
gcloud secrets versions access latest --secret=terraform-db-password
```

## Contributing

Please ensure all changes maintain the security posture of the pipeline:
1. Never commit sensitive data
2. Always use Secret Manager for secrets
3. Test changes in a non-production environment first
4. Review IAM permissions regularly

## License

This project is provided as-is for demonstration purposes.