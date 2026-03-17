# GCP Assured Workloads Demo

Infrastructure as Code for deploying workloads inside a Google Cloud [Assured Workloads](https://cloud.google.com/assured-workloads) environment. Uses Terraform and Cloud Build with FedRAMP High controls.

## Prerequisites

- GCP project inside an Assured Workloads folder
- `gcloud` CLI >= 403.0.0
- Terraform >= 1.0
- Enhanced or Premium Cloud Customer Care (for adjudicated support)

## Quick Start

```bash
# Bootstrap (one-time): state bucket, secrets, service accounts
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"
export TERRAFORM_STATE_BUCKET="your-tfstate-bucket"
export DB_PASSWORD="your-db-password"
./setup-infrastructure.sh

# Deploy
terraform init
terraform apply

# Validate compliance posture
./validate-state.sh
./validate-state.sh --report compliance-report.json

# Validate Terraform before committing
./validate-terraform.sh

# Tear down
terraform destroy
```

## Project Structure

```
.
├── main.tf                   # Infrastructure resources
├── variables.tf              # Input variables
├── outputs.tf                # Output values
├── providers.tf              # Provider configuration
├── backend.tf                # Remote state (GCS)
├── cloudbuild.yaml           # CI/CD pipeline
├── setup-infrastructure.sh   # Bootstrap script
├── validate-state.sh         # Compliance validation
└── validate-terraform.sh     # Pre-commit checks
```

## CI/CD

Cloud Build triggers on push to `main` with manual approval required. Pipeline runs `terraform init`, `validate`, `plan`, and `apply`. Secrets pulled from Secret Manager with `user-managed` replication pinned to the compliant region.

Build configuration: E2 machine types, `CLOUD_LOGGING_ONLY` (logs stay in GCP).

## Notes

- Use `console.us.cloud.google.com` for FedRAMP High (jurisdictional console)
- Secret Manager requires `--replication-policy=user-managed` inside Assured Workloads
- Developer Connect GitHub connections must use the data-residency-compliant option (Console only, not CLI)
- See the [blog post](https://ethantroy.dev/posts/google-assured-workloads-are-not-a-magic-bullet-for-fedramp-or-ilx/) for a detailed walkthrough

## License

MIT
