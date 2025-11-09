# Google Assured Workloads Demo: "Not a Magic Bullet"

## Executive Summary

This repository demonstrates that **Google Assured Workloads is not a magic bullet for FedRAMP High / DoD IL5 compliance**. While Assured Workloads provides essential platform-level controls (data residency, personnel access restrictions, FIPS 140-2 encryption), it **does not automatically enforce service-specific security configurations** required for full compliance.

**Key Finding**: You can deploy insecure infrastructure within an Assured Workloads environment and violate FedRAMP/IL5 controls if you don't configure services properly.

## What This Demo Shows

This repository contains a complete, working example of an AI inference platform (llama.cpp) deployed on GKE, progressing through **9 commits** from non-compliant to fully compliant:

### Commit 1: Non-Compliant Baseline (10 Violations)
Intentionally insecure configuration showing what Assured Workloads **doesn't prevent**:

1. **Public GKE cluster** - Control plane and nodes accessible from internet (SC-7)
2. **No Binary Authorization or Workload Identity** - Unsigned images, excessive permissions (CM-7, IA-2, AC-6)
3. **No GKE secrets encryption** - Kubernetes secrets in etcd without CMEK (SC-28, SC-12)
4. **Cloud SQL public access** - 0.0.0.0/0 authorized, no SSL required, no CMEK (AC-17, SC-8, SC-28)
5. **Publicly accessible Storage** - No CMEK, no UBLA, allUsers access (AC-3, SC-28)
6. **Overprivileged IAM** - Editor role, long-lived service account keys (AC-6, IA-5)
7. **Missing network controls** - No VPC-SC, no Private Google Access, no firewall rules (SC-7)
8. **Minimal audit logging** - 30-day retention, no CMEK, Data Access logs disabled (AU-2, AU-9, AU-11)
9. **No vulnerability management** - No scanning, no auto-updates (SI-2, RA-5)
10. **Public LLM endpoint** - llama.cpp exposed via LoadBalancer, no authentication, no mTLS (SC-7, SC-8, AC-2)

**Current Status**: Commit 1 deployed ✅

### Commits 2-9: Incremental Remediation (Coming Soon)
Each subsequent commit fixes specific violation categories:
- Commit 2: GKE compute security (private cluster, Binary Auth, Workload Identity)
- Commit 3: Data encryption with CMEK
- Commit 4: IAM and networking hardening
- Commit 5: Comprehensive audit logging
- Commit 6: Vulnerability management
- Commit 7: Disaster recovery and backups
- Commit 8: Service mesh and mTLS
- Commit 9: Compliance testing documentation

## Demo Application: llama.cpp

We deploy [llama.cpp](https://github.com/ggml-org/llama.cpp), an open-source LLM inference server, to demonstrate realistic compliance requirements for AI/ML workloads:

- **Model**: TinyLlama-1.1B (quantized to ~1GB for cost efficiency)
- **Deployment**: Kubernetes on GKE
- **API**: OpenAI-compatible REST API
- **Security Surface**: Model files (CMEK), API endpoints (mTLS), network exposure (private cluster)

## What Assured Workloads Actually Enforces

### ✅ Automatic Protections (Platform-Level)
- Data residency restricted to US regions
- Support personnel limited to FedRAMP-adjudicated US citizens
- FIPS 140-2 validated encryption (platform level)
- Only FedRAMP-authorized services allowed
- Logical segmentation of compliance boundary

### ❌ Does NOT Enforce (Service-Level - Your Responsibility)
- Service-specific security configurations (GKE, Cloud SQL, Storage)
- CMEK implementation on individual resources
- Network security policies (VPC-SC, firewall rules, Private Google Access)
- IAM least privilege configurations
- Audit logging completeness and retention
- Vulnerability management and patching
- Backup retention and disaster recovery settings
- Application-layer security (authentication, mTLS, secrets management)

## Architecture

### Commit 1: Non-Compliant Architecture
```
Internet (Public Access)
        │
        ├──> Public GKE Control Plane
        │    └──> Public Node IPs
        │         └──> llama.cpp Pod (Public LoadBalancer)
        │              ├──> Reads from Public GCS Bucket (allUsers)
        │              └──> Connects to Cloud SQL (0.0.0.0/0)
        │
        └──> Anyone can access LLM API (no auth)
```

### Commits 2-9: Compliant Architecture (Target State)
```
Private VPC with VPC Service Controls
        │
        ├──> Private GKE Control Plane (172.16.0.0/28)
        │    └──> Private Nodes (no external IPs)
        │         └──> llama.cpp Pod (ClusterIP only)
        │              ├──> Istio Sidecar (mTLS STRICT)
        │              ├──> Workload Identity (no SA keys)
        │              ├──> Reads from Private GCS (CMEK, UBLA)
        │              └──> Connects to Cloud SQL (Private IP, CMEK, SSL)
        │
        ├──> Binary Authorization (signed images only)
        ├──> Network Policies (zero-trust micro-segmentation)
        ├──> Cloud Audit Logs (365-day retention, CMEK)
        └──> Continuous Vulnerability Scanning
```

## Prerequisites

- GCP project within an Assured Workloads folder (FedRAMP High or IL5 compliance regime)
- `gcloud` CLI installed and authenticated
- Terraform >= 1.0
- kubectl installed
- (Optional) tfsec for security scanning

## Local Development and Testing

### Validate Before Committing

To catch errors early, run the validation script before pushing:

```bash
chmod +x validate-terraform.sh
./validate-terraform.sh
```

This script checks:
1. ✅ Terraform formatting (`terraform fmt -check`)
2. ✅ Terraform initialization (`terraform init`)
3. ✅ Configuration validation (`terraform validate`)
4. ✅ Security scanning with tfsec (if installed)

**Install tfsec (optional but recommended):**
```bash
# macOS
brew install tfsec

# Linux
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Windows
choco install tfsec
```

## Quick Start

### 1. Set Environment Variables
```bash
export PROJECT_ID="your-assured-workloads-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Deploy Non-Compliant Baseline (Commit 1)
```bash
# Set database password
export TF_VAR_project_id=$PROJECT_ID
export TF_VAR_region=$REGION
export TF_VAR_zone=$ZONE
export TF_VAR_db_password="temporary-password-123"

# Deploy all violations
terraform apply -auto-approve
```

### 4. Verify Violations

**Test Public GKE Access:**
```bash
terraform output cluster_endpoint
curl -k https://$(terraform output -raw cluster_endpoint)/version
```

**Test Public llama.cpp Endpoint:**
```bash
LLAMA_IP=$(kubectl get svc llama-server -n llama-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$LLAMA_IP/v1/models
```

**Test Public Storage:**
```bash
BUCKET=$(terraform output -raw bucket_name)
gsutil ls gs://$BUCKET  # Anyone can list!
```

**Test Public SQL:**
```bash
SQL_IP=$(terraform output -raw sql_public_ip)
psql -h $SQL_IP -U demo-user -d demo-db  # Accessible from anywhere!
```

## Compliance Control Mappings

| Violation | NIST 800-53 Rev 5 Controls | FedRAMP Impact | IL5 Impact |
|-----------|---------------------------|----------------|------------|
| Public GKE cluster | SC-7, SC-7(4), SC-7(5), AC-4 | HIGH | CRITICAL |
| No Binary Authorization | CM-7, SI-7 | MEDIUM | HIGH |
| No Workload Identity | IA-2, AC-6 | HIGH | HIGH |
| No secrets CMEK | SC-28, SC-12 | MEDIUM | HIGH |
| Cloud SQL public/no CMEK | AC-17, SC-8, SC-28, SC-12 | HIGH | CRITICAL |
| Public Storage/no CMEK | AC-3, SC-28, SC-12 | HIGH | CRITICAL |
| Overprivileged IAM | AC-2, AC-6, IA-5 | HIGH | HIGH |
| Missing network controls | SC-7, SC-7(5) | HIGH | CRITICAL |
| Minimal audit logging | AU-2, AU-6, AU-9, AU-11 | HIGH | CRITICAL |
| No vulnerability mgmt | SI-2, RA-5, CM-6 | MEDIUM | HIGH |

## Repository Structure

```
.
├── README.md                    # This file
├── backend.tf                   # Terraform remote state config (GCS)
├── providers.tf                 # Terraform provider configuration
├── variables.tf                 # Input variables (project_id, region, db_password)
├── outputs.tf                   # Output values (cluster, SQL, storage)
├── main.tf                      # All infrastructure (Commit 1: non-compliant)
├── cloudbuild.yaml              # CI/CD pipeline configuration
├── .gitignore                   # Excludes .tfstate, .tfvars, secrets
└── blog.md                      # Detailed writeup (local only, not committed)
```

## Demonstration Flow

### Act 1: "The Violation" (Commit 1)
1. Deploy non-compliant infrastructure
2. Show public access to LLM API: `curl http://$LLAMA_IP/v1/models`
3. Show unencrypted data in GCS: `gsutil ls gs://$BUCKET`
4. Show SQL accessible from 0.0.0.0/0
5. Run Assured Workloads compliance scan → **Shows violations**

### Act 2: "The Remediation" (Commits 2-8)
1. Fix GKE security (private, Binary Auth, Workload Identity)
2. Add CMEK encryption everywhere
3. Harden IAM and networking
4. Enable comprehensive audit logging
5. Add vulnerability scanning
6. Configure DR and backups
7. Deploy service mesh with mTLS

### Act 3: "The Validation" (Commit 9)
1. Re-run compliance scan → **Compliant**
2. Verify mTLS: `istioctl authn tls-check`
3. Verify private access only (public curl fails)
4. Verify CMEK encryption on all data
5. Verify audit logs with 365-day retention

## Key Takeaways

1. **Assured Workloads ≠ Automatic Compliance**: It provides a foundation, not a complete solution
2. **Shared Responsibility**: Google secures the platform; you secure your configurations
3. **Configuration Drift is Dangerous**: Misconfigurations can violate controls even within AW
4. **Defense in Depth Required**: Layer multiple controls (CMEK + VPC-SC + Network Policies + mTLS)
5. **Automation is Essential**: Use IaC (Terraform) + Policy-as-Code (OPA/Gatekeeper) + continuous monitoring

## Resources

- [Google Assured Workloads Documentation](https://cloud.google.com/assured-workloads/docs)
- [FedRAMP High Baseline](https://www.fedramp.gov/documents/)
- [NIST 800-53 Rev 5](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf)
- [DoD Cloud Computing SRG](https://dl.dod.cyber.mil/wp-content/uploads/cloud/SRG/index.html)
- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)

## License

MIT License - Provided for educational and demonstration purposes only.

## Disclaimer

This repository intentionally deploys insecure infrastructure for demonstration purposes. **DO NOT use Commit 1 configurations in production.** Always follow security best practices and compliance requirements for your specific use case.

---

**Current Status**: Commit 1 (Non-Compliant Baseline) - 10 violations deployed
**Next**: Commit 2 will fix GKE compute security violations
