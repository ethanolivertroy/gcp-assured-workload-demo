# Vertex AI Guard Rails in Google Assured Workloads

## Executive Summary

This document details **what guard rails Google Assured Workloads provides for Vertex AI** and what security configurations remain your responsibility for FedRAMP High / DoD IL5 compliance.

**Key Finding**: Similar to other GCP services, Assured Workloads provides **platform-level controls** for Vertex AI but **does not automatically enforce all service-specific security configurations** required for full compliance. Organizations must layer additional controls on top of Assured Workloads to meet regulatory requirements.

### What This Document Covers

- ✅ **Platform-level controls** enforced by Assured Workloads for Vertex AI
- ❌ **Service-level configurations** you must implement
- 🔒 **Organization policy constraints** specific to Vertex AI
- 📋 **NIST 800-53 control mappings** for AI/ML workloads
- 🧪 **Validation commands** to verify compliance posture

---

## FedRAMP High Authorization Status

**Vertex AI is FedRAMP High authorized** and available within Google Assured Workloads environments as of March 2025. This includes:

✅ **Authorized Vertex AI Services**:
- Vertex AI Platform (training, prediction, model management)
- Vertex AI Search
- Generative AI on Vertex AI (including Gemini models)
- Vertex AI Vector Search
- Vertex AI Agent Builder
- Third-party models (Claude 3.5, Llama, etc.) via Model Garden

✅ **Supported Compliance Regimes**:
- FedRAMP High (US Federal agencies)
- DoD Impact Level 5 (IL5) with Assured Workloads
- ITAR (International Traffic in Arms Regulations)
- CJIS (Criminal Justice Information Services)

---

## What Assured Workloads Enforces for Vertex AI

### ✅ Automatic Protections (Platform-Level)

Assured Workloads **automatically enforces** these controls for Vertex AI resources:

#### 1. **Data Residency and Sovereignty**
- **Control**: All Vertex AI data (training data, models, logs) restricted to approved US regions
- **Mechanism**: Organization policy constraints on resource locations
- **NIST**: SC-12 (Cryptographic Key Management), SA-9 (External System Services)
- **Impact**: CRITICAL - Prevents data from leaving approved geographic boundaries

```bash
# Verification
gcloud resource-manager org-policies describe \
  constraints/gcp.resourceLocations \
  --project=$PROJECT_ID
```

#### 2. **Personnel Access Restrictions**
- **Control**: Support personnel limited to FedRAMP-adjudicated US citizens with appropriate clearances
- **Mechanism**: Google's internal access controls within Assured Workloads folders
- **NIST**: AC-2 (Account Management), PS-3 (Personnel Screening)
- **Impact**: HIGH - Ensures only cleared personnel can access infrastructure

#### 3. **FIPS 140-2 Validated Encryption**
- **Control**: All data encrypted at rest using FIPS 140-2 validated cryptographic modules
- **Mechanism**: Google Cloud platform-level encryption (transparent to users)
- **NIST**: SC-13 (Cryptographic Protection), SC-28 (Protection of Information at Rest)
- **Impact**: HIGH - Meets federal cryptographic requirements

#### 4. **Approved Services Only**
- **Control**: Only FedRAMP High authorized Vertex AI services can be used
- **Mechanism**: Organization policies block non-authorized services
- **NIST**: SA-9 (External System Services)
- **Impact**: CRITICAL - Prevents use of non-compliant AI services

```bash
# Check allowed services
gcloud resource-manager org-policies describe \
  constraints/gcp.restrictServiceUsage \
  --project=$PROJECT_ID
```

#### 5. **Audit Logging (Basic)**
- **Control**: Admin Activity logs automatically enabled for all Vertex AI operations
- **Mechanism**: Platform-level Cloud Audit Logs
- **NIST**: AU-2 (Event Logging) - PARTIAL
- **Impact**: MEDIUM - Provides basic audit trail

---

## What Assured Workloads Does NOT Enforce

### ❌ Your Responsibility (Service-Level Configuration)

These **critical security controls are NOT automatically enforced** and must be manually configured:

### 1. Customer-Managed Encryption Keys (CMEK)

**Gap**: Vertex AI datasets, models, and endpoints use Google-managed encryption by default.

**Risk**: CRITICAL - Cannot demonstrate cryptographic key management required by SC-12, SC-28

**NIST Controls**: SC-12 (Cryptographic Key Management), SC-28 (Protection at Rest)

**Remediation Required**:
```bash
# Create KMS keyring for Vertex AI
gcloud kms keyrings create vertex-ai-keyring \
  --location=$REGION

# Create encryption key
gcloud kms keys create vertex-ai-key \
  --location=$REGION \
  --keyring=vertex-ai-keyring \
  --purpose=encryption

# Use CMEK when creating datasets
gcloud ai datasets create \
  --display-name="my-dataset" \
  --region=$REGION \
  --encryption-kms-key-name="projects/$PROJECT_ID/locations/$REGION/keyRings/vertex-ai-keyring/cryptoKeys/vertex-ai-key"
```

**What Must Use CMEK**:
- ✅ Vertex AI Datasets
- ✅ Vertex AI Models
- ✅ Vertex AI Endpoints
- ✅ Vertex AI Training Jobs (output artifacts)
- ✅ Vertex AI Pipelines
- ✅ Vertex AI Notebook instances (persistent disks)

---

### 2. Private Networking Configuration

**Gap**: Vertex AI endpoints can be publicly accessible by default.

**Risk**: CRITICAL - Violates SC-7 (Boundary Protection), AC-17 (Remote Access)

**NIST Controls**: SC-7 (Boundary Protection), SC-7(4), AC-17 (Remote Access)

**Remediation Required**:
```bash
# Deploy endpoint with VPC peering (private access only)
gcloud ai endpoints create \
  --display-name="private-llm-endpoint" \
  --region=$REGION \
  --network="projects/$PROJECT_ID/global/networks/my-vpc" \
  --enable-private-service-connect

# Verify no public IPs
gcloud ai endpoints describe $ENDPOINT_ID \
  --region=$REGION \
  --format="get(deployedModels[].privateEndpoints)"
```

**Required Network Controls**:
- ✅ VPC Service Controls perimeter for Vertex AI
- ✅ Private Service Connect for endpoints
- ✅ VPC Peering for Workbench notebooks
- ✅ Private Google Access enabled on subnets
- ✅ No public IP addresses on endpoints or notebooks

---

### 3. Model Access Control and Governance

**Gap**: All Model Garden models accessible by default, including third-party models.

**Risk**: HIGH - Uncontrolled model access violates CM-7 (Least Functionality), SA-10 (Developer Configuration Management)

**NIST Controls**: CM-7 (Least Functionality), SA-10 (Developer Configuration Management)

**Remediation Required**:
```bash
# Create organization policy to restrict Model Garden access
cat <<EOF > model-policy.yaml
name: organizations/$ORG_ID/policies/aiplatform.allowedModelGardenModels
spec:
  rules:
  - values:
      deniedValues:
      - "publishers/anthropic/*"  # Block specific publishers
      - "publishers/meta/*"
      allowedValues:
      - "publishers/google/*"      # Allow only Google models
EOF

gcloud org-policies set-policy model-policy.yaml
```

**Model Governance Requirements**:
- ✅ Restrict which foundation models can be used
- ✅ Block unapproved third-party models
- ✅ Require model attestation and provenance
- ✅ Audit log all model access and deployment
- ✅ Implement model versioning and lifecycle management

---

### 4. Workload Identity and IAM Least Privilege

**Gap**: Overly permissive IAM roles (e.g., Vertex AI Administrator) can be granted.

**Risk**: HIGH - Violates AC-6 (Least Privilege), AC-2 (Account Management)

**NIST Controls**: AC-6 (Least Privilege), AC-2 (Account Management)

**Remediation Required**:
```bash
# Instead of broad roles, use specific predefined roles:
# ❌ DON'T: roles/aiplatform.admin
# ✅ DO: roles/aiplatform.user + specific resource-level grants

# Grant minimal permissions for training jobs
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:ml-pipeline@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user" \
  --condition='expression=resource.name.startsWith("projects/'$PROJECT_ID'/locations/'$REGION'/trainingPipelines/"),title=training-only'

# Use Workload Identity for GKE-based training
kubectl create serviceaccount ml-workload-sa -n ml-team
gcloud iam service-accounts add-iam-policy-binding \
  ml-pipeline@$PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[ml-team/ml-workload-sa]"
```

**IAM Best Practices**:
- ✅ Never use `aiplatform.admin` role in production
- ✅ Use Workload Identity for service-to-service authentication
- ✅ Implement resource-level IAM conditions
- ✅ No long-lived service account keys (blocked by Assured Workloads)
- ✅ Use Cloud Scheduler or Cloud Run jobs for automation (not user credentials)

---

### 5. Comprehensive Audit Logging

**Gap**: Data Access logs (read/write operations) disabled by default.

**Risk**: CRITICAL - Violates AU-2 (Event Logging), AU-3 (Content of Audit Records)

**NIST Controls**: AU-2 (Event Logging), AU-9 (Protection of Audit Information), AU-11 (Audit Record Retention)

**Remediation Required**:
```bash
# Enable Data Access logs for Vertex AI
cat <<EOF > audit-config.yaml
auditConfigs:
- service: aiplatform.googleapis.com
  auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
EOF

gcloud projects set-iam-policy $PROJECT_ID audit-config.yaml

# Extend log retention to 365 days (FedRAMP requirement)
gcloud logging buckets update _Default \
  --location=global \
  --retention-days=365 \
  --locked

# Add CMEK for log encryption
gcloud logging buckets update _Default \
  --location=global \
  --cmek-kms-key-name="projects/$PROJECT_ID/locations/$REGION/keyRings/logging-keyring/cryptoKeys/log-key"
```

**Audit Requirements**:
- ✅ All log types enabled (ADMIN_READ, DATA_READ, DATA_WRITE)
- ✅ 365+ day retention with immutable lock
- ✅ CMEK encryption for log buckets
- ✅ Log sinks to long-term archive (7-year retention)
- ✅ Real-time alerts for sensitive operations

---

### 6. VPC Service Controls Perimeter

**Gap**: Vertex AI resources not protected by network security boundary.

**Risk**: CRITICAL - Violates SC-7(8) (Route Traffic to Authenticated Proxy), AC-4 (Information Flow Enforcement)

**NIST Controls**: SC-7(8), AC-4 (Information Flow Enforcement)

**Remediation Required**:
```bash
# Create VPC Service Controls perimeter for Vertex AI
gcloud access-context-manager perimeters create vertex-ai-perimeter \
  --title="Vertex AI Perimeter" \
  --resources="projects/$PROJECT_NUMBER" \
  --restricted-services="aiplatform.googleapis.com,notebooks.googleapis.com" \
  --policy=$POLICY_ID

# Allow ingress from trusted sources only
gcloud access-context-manager perimeters update vertex-ai-perimeter \
  --add-ingress-policies=ingress-policy.yaml \
  --policy=$POLICY_ID
```

**VPC-SC Requirements**:
- ✅ Perimeter includes all Vertex AI projects
- ✅ Restricted services: `aiplatform.googleapis.com`, `notebooks.googleapis.com`
- ✅ Ingress/egress policies for data science workstations
- ✅ No Bridge perimeters to non-compliant projects

---

### 7. Secrets Management for Model Credentials

**Gap**: API keys, credentials stored in code or environment variables.

**Risk**: HIGH - Violates IA-5 (Authenticator Management), SC-28 (Protection at Rest)

**NIST Controls**: IA-5 (Authenticator Management), SC-28

**Remediation Required**:
```bash
# Store model API keys in Secret Manager with CMEK
gcloud secrets create vertex-api-key \
  --replication-policy="automatic" \
  --kms-key-name="projects/$PROJECT_ID/locations/$REGION/keyRings/secrets-keyring/cryptoKeys/secrets-key"

echo -n "your-api-key" | gcloud secrets versions add vertex-api-key --data-file=-

# Grant access to service account only
gcloud secrets add-iam-policy-binding vertex-api-key \
  --member="serviceAccount:ml-pipeline@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Access in code
from google.cloud import secretmanager
client = secretmanager.SecretManagerServiceClient()
name = f"projects/{project_id}/secrets/vertex-api-key/versions/latest"
response = client.access_secret_version(request={"name": name})
api_key = response.payload.data.decode("UTF-8")
```

**Secrets Best Practices**:
- ✅ All credentials in Secret Manager with CMEK
- ✅ No secrets in code, environment variables, or logs
- ✅ Automatic secret rotation (90 days)
- ✅ Audit logs for secret access

---

### 8. Training Job Security and Isolation

**Gap**: Training jobs run with default service accounts and no network isolation.

**Risk**: HIGH - Violates AC-6 (Least Privilege), SC-7 (Boundary Protection)

**NIST Controls**: AC-6, SC-7, CM-7

**Remediation Required**:
```python
# Use custom service account with minimal permissions
from google.cloud import aiplatform

aiplatform.init(
    project=project_id,
    location=region,
    encryption_spec_key_name=cmek_key,  # CMEK required
    staging_bucket=f"gs://{project_id}-vertex-staging",
)

# Create training job with security controls
job = aiplatform.CustomTrainingJob(
    display_name="secure-training-job",
    container_uri="us-docker.pkg.dev/vertex-ai/training/tf-cpu.2-12:latest",
    model_serving_container_image_uri="us-docker.pkg.dev/vertex-ai/prediction/tf2-cpu.2-12:latest",
)

model = job.run(
    dataset=my_dataset,
    replica_count=1,
    machine_type="n1-standard-4",
    service_account="ml-training@$PROJECT_ID.iam.gserviceaccount.com",  # Custom SA
    network="projects/$PROJECT_NUMBER/global/networks/my-vpc",  # Private network
    enable_web_access=False,  # No external access during training
    boot_disk_type="pd-ssd",
    boot_disk_size_gb=100,
)
```

**Training Security Requirements**:
- ✅ Custom service accounts with least privilege
- ✅ Private VPC for training jobs (no internet access)
- ✅ CMEK for training artifacts and checkpoints
- ✅ Container image scanning and verification
- ✅ No web access during training (`enable_web_access=False`)
- ✅ Disk encryption for boot disks

---

### 9. Vertex AI Workbench Security

**Gap**: Notebook instances can have public IPs and permissive access.

**Risk**: CRITICAL - Violates SC-7 (Boundary Protection), AC-2 (Account Management)

**NIST Controls**: SC-7, AC-2, IA-2

**Remediation Required**:
```bash
# Create Workbench instance with security hardening
gcloud workbench instances create secure-notebook \
  --location=$REGION \
  --machine-type=n1-standard-4 \
  --no-public-ip \
  --network="projects/$PROJECT_ID/global/networks/my-vpc" \
  --subnet="projects/$PROJECT_ID/regions/$REGION/subnetworks/my-subnet" \
  --service-account="notebook-user@$PROJECT_ID.iam.gserviceaccount.com" \
  --boot-disk-type=PD_SSD \
  --boot-disk-size=100GB \
  --boot-disk-encryption=CMEK \
  --boot-disk-kms-key="projects/$PROJECT_ID/locations/$REGION/keyRings/vertex-ai-keyring/cryptoKeys/vertex-ai-key" \
  --metadata="enable-oslogin=TRUE,block-project-ssh-keys=TRUE,serial-port-enable=FALSE" \
  --disable-root-access
```

**Workbench Security Requirements**:
- ✅ No public IPs (VPN or IAP for access)
- ✅ VPC peering for private access
- ✅ CMEK for persistent disks
- ✅ OS Login enforced (no SSH keys)
- ✅ Root access disabled
- ✅ Automatic idle shutdown (cost + security)
- ✅ Container-based notebooks preferred over VM-based

---

### 10. Model Deployment Endpoint Security

**Gap**: Model endpoints deployed with public access by default.

**Risk**: CRITICAL - Violates SC-7 (Boundary Protection), AC-3 (Access Enforcement)

**NIST Controls**: SC-7, AC-3, SC-8 (Transmission Confidentiality)

**Remediation Required**:
```python
# Deploy model to private endpoint
from google.cloud import aiplatform

endpoint = aiplatform.Endpoint.create(
    display_name="private-llm-endpoint",
    network="projects/$PROJECT_NUMBER/global/networks/my-vpc",
    enable_private_service_connect=True,  # Private endpoint
    encryption_spec_key_name=cmek_key,
)

# Deploy model with authentication required
model.deploy(
    endpoint=endpoint,
    deployed_model_display_name="secure-model-v1",
    machine_type="n1-standard-4",
    min_replica_count=2,  # For HA
    max_replica_count=10,
    traffic_percentage=100,
    service_account="model-serving@$PROJECT_ID.iam.gserviceaccount.com",
    enable_access_logging=True,  # Audit all predictions
)

# Add authentication via API Gateway or Load Balancer
# Use mTLS for inter-service communication
# Implement rate limiting and request validation
```

**Endpoint Security Requirements**:
- ✅ Private Service Connect (no public IPs)
- ✅ Authentication required (API keys or OAuth)
- ✅ mTLS for production endpoints
- ✅ Request/response logging enabled
- ✅ Rate limiting and DDoS protection
- ✅ Input validation and sanitization

---

### 11. AI-Specific Security Risks

**Gap**: Vertex AI doesn't automatically protect against prompt injection, model inversion, or data poisoning.

**Risk**: HIGH - AI-specific attacks not covered by traditional controls

**NIST Controls**: SA-15 (Development Process and Standards), SI-10 (Information Input Validation)

**Remediation Required**:
```python
# Implement input validation for prompts
import re
from google.cloud import aiplatform_v1

def validate_prompt(prompt: str) -> bool:
    """Validate and sanitize user input to prevent injection attacks."""
    # Block prompt injection patterns
    dangerous_patterns = [
        r"ignore previous instructions",
        r"system:",
        r"<script>",
        r"DROP TABLE",
    ]
    
    for pattern in dangerous_patterns:
        if re.search(pattern, prompt, re.IGNORECASE):
            return False
    
    # Limit prompt length
    if len(prompt) > 4000:
        return False
    
    return True

# Use Vertex AI's built-in safety filters
prediction_client = aiplatform_v1.PredictionServiceClient()

safety_settings = {
    "harm_block_threshold": "BLOCK_LOW_AND_ABOVE",
    "categories": [
        "HARM_CATEGORY_HATE_SPEECH",
        "HARM_CATEGORY_DANGEROUS_CONTENT",
        "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        "HARM_CATEGORY_HARASSMENT",
    ],
}

# Monitor for model abuse and drift
# Implement output validation
# Use Sensitive Data Protection to scan inputs/outputs
```

**AI Security Requirements**:
- ✅ Input validation and sanitization
- ✅ Output filtering for sensitive data
- ✅ Prompt injection detection
- ✅ Model behavior monitoring (drift detection)
- ✅ Adversarial testing and red teaming
- ✅ Data lineage tracking
- ✅ Model explainability and interpretability

---

## Organization Policy Constraints for Vertex AI

### Custom Constraints for Training Jobs

```yaml
# Restrict machine types to approved list
name: organizations/ORG_ID/customConstraints/aiplatform.allowedMachineTypes
displayName: "Allowed Vertex AI Machine Types"
actionType: ALLOW
condition: >
  resource.masterConfig.machineSpec.machineType in [
    "n1-standard-4",
    "n1-standard-8",
    "n1-highmem-4"
  ]
resourceTypes:
- aiplatform.googleapis.com/CustomJob
- aiplatform.googleapis.com/HyperparameterTuningJob
```

### Enforce CMEK Encryption

```yaml
# Require CMEK for all Vertex AI resources
name: organizations/ORG_ID/customConstraints/aiplatform.requireCMEK
displayName: "Require CMEK for Vertex AI"
actionType: DENY
condition: >
  !has(resource.encryptionSpec.kmsKeyName) ||
  resource.encryptionSpec.kmsKeyName == ""
resourceTypes:
- aiplatform.googleapis.com/Dataset
- aiplatform.googleapis.com/Model
- aiplatform.googleapis.com/Endpoint
```

### Restrict to US Regions

```yaml
# Enforce data residency
name: organizations/ORG_ID/policies/gcp.resourceLocations
spec:
  rules:
  - values:
      allowedValues:
      - in:us-locations  # Only US regions
      deniedValues:
      - in:eu-locations
      - in:asia-locations
```

---

## Compliance Validation Checklist

### Platform-Level (Assured Workloads - Automatic)

- ✅ Data residency restricted to US regions
- ✅ Support personnel limited to cleared US citizens
- ✅ FIPS 140-2 encryption enabled
- ✅ Only FedRAMP-authorized services available
- ✅ Admin Activity logs enabled

### Service-Level (Your Responsibility - Manual)

- [ ] CMEK configured for all Vertex AI resources
- [ ] Private networking (VPC-SC perimeter)
- [ ] Model access controls via organization policies
- [ ] IAM least privilege (no broad admin roles)
- [ ] Data Access logs enabled (365-day retention)
- [ ] Logs encrypted with CMEK
- [ ] Workbench notebooks private (no public IPs)
- [ ] Training jobs use custom service accounts
- [ ] Model endpoints private (Private Service Connect)
- [ ] Secrets in Secret Manager with CMEK
- [ ] Input validation and output filtering
- [ ] Adversarial testing and red teaming

---

## NIST 800-53 Control Mapping

| NIST Control | Description | AW Coverage | Your Action Required |
|--------------|-------------|-------------|----------------------|
| **AC-2** | Account Management | ❌ | Configure IAM least privilege |
| **AC-3** | Access Enforcement | ❌ | VPC-SC perimeter, private endpoints |
| **AC-4** | Information Flow Enforcement | ❌ | VPC-SC, network policies |
| **AC-6** | Least Privilege | ❌ | Custom IAM roles, conditions |
| **AC-17** | Remote Access | ❌ | Private endpoints, VPN/IAP |
| **AU-2** | Event Logging | ⚠️ PARTIAL | Enable Data Access logs |
| **AU-9** | Protection of Audit Information | ❌ | CMEK for log buckets |
| **AU-11** | Audit Record Retention | ❌ | 365-day retention with lock |
| **CM-7** | Least Functionality | ❌ | Model access policies |
| **IA-2** | Identification and Authentication | ❌ | Workload Identity, OAuth |
| **IA-5** | Authenticator Management | ✅ | SA key creation blocked by AW |
| **SA-9** | External System Services | ✅ | Only FedRAMP services allowed |
| **SA-10** | Developer Configuration Management | ❌ | Model governance, provenance |
| **SA-15** | Development Process Standards | ❌ | Secure ML pipeline |
| **SC-7** | Boundary Protection | ❌ | VPC-SC, private endpoints |
| **SC-8** | Transmission Confidentiality | ❌ | mTLS, Private Service Connect |
| **SC-12** | Cryptographic Key Management | ✅ | FIPS 140-2 (+ CMEK for control) |
| **SC-13** | Cryptographic Protection | ✅ | FIPS 140-2 validated |
| **SC-28** | Protection at Rest | ⚠️ PARTIAL | FIPS 140-2 (+ CMEK required) |
| **SI-10** | Information Input Validation | ❌ | Prompt validation, sanitization |

**Legend**:
- ✅ **Covered** by Assured Workloads (automatic)
- ⚠️ **PARTIAL** coverage (basic controls, more needed)
- ❌ **Not covered** (your responsibility)

---

## Example: Secure Vertex AI Pipeline

```python
# secure_vertex_pipeline.py
from google.cloud import aiplatform
from kfp.v2 import dsl
from kfp.v2.dsl import component

# Initialize with security settings
PROJECT_ID = "your-fedramp-project"
REGION = "us-central1"
CMEK_KEY = "projects/PROJECT_ID/locations/us-central1/keyRings/vertex-ai/cryptoKeys/ai-key"
VPC_NETWORK = "projects/PROJECT_ID/global/networks/secure-vpc"
SERVICE_ACCOUNT = "ml-pipeline@PROJECT_ID.iam.gserviceaccount.com"

aiplatform.init(
    project=PROJECT_ID,
    location=REGION,
    encryption_spec_key_name=CMEK_KEY,
    staging_bucket=f"gs://{PROJECT_ID}-vertex-staging",
    network=VPC_NETWORK,
)

@component(
    base_image="us-docker.pkg.dev/vertex-ai/training/tf-cpu.2-12:latest",
    packages_to_install=["pandas", "scikit-learn"],
)
def secure_training_component(
    dataset_id: str,
    model_output_path: str,
):
    """Training component with security controls."""
    # Input validation
    import re
    if not re.match(r'^[a-zA-Z0-9_-]+$', dataset_id):
        raise ValueError("Invalid dataset ID")
    
    # Training logic here
    print(f"Training on dataset: {dataset_id}")
    
    # Model saved to CMEK-encrypted bucket
    print(f"Model saved to: {model_output_path}")

@dsl.pipeline(
    name="secure-ml-pipeline",
    description="FedRAMP-compliant ML pipeline",
)
def secure_pipeline():
    training_task = secure_training_component(
        dataset_id="my-dataset",
        model_output_path=f"gs://{PROJECT_ID}-models/model.pkl",
    )

# Compile and run with security settings
from kfp.v2 import compiler

compiler.Compiler().compile(
    pipeline_func=secure_pipeline,
    package_path="secure_pipeline.json",
)

# Run pipeline with service account
job = aiplatform.PipelineJob(
    display_name="secure-ml-pipeline-run",
    template_path="secure_pipeline.json",
    enable_caching=False,  # For reproducibility
    encryption_spec_key_name=CMEK_KEY,
    service_account=SERVICE_ACCOUNT,
    network=VPC_NETWORK,
)

job.submit()
```

---

## Validation Commands

### Check Data Residency
```bash
# Verify all Vertex AI resources in approved regions
gcloud ai models list --region=us-central1 --format="table(name,region)"
gcloud ai endpoints list --region=us-central1 --format="table(name,region)"
```

### Verify CMEK Encryption
```bash
# Check dataset encryption
gcloud ai datasets describe DATASET_ID \
  --region=$REGION \
  --format="get(encryptionSpec.kmsKeyName)"

# Check model encryption
gcloud ai models describe MODEL_ID \
  --region=$REGION \
  --format="get(encryptionSpec.kmsKeyName)"
```

### Check Private Networking
```bash
# Verify endpoints are private
gcloud ai endpoints list \
  --region=$REGION \
  --format="table(name,network,enablePrivateServiceConnect)"

# Verify VPC-SC perimeter
gcloud access-context-manager perimeters describe $PERIMETER_NAME \
  --policy=$POLICY_ID \
  --format="get(status.restrictedServices)"
```

### Audit Logging Status
```bash
# Verify Data Access logs enabled
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="auditConfigs[].service" \
  --filter="auditConfigs.service:aiplatform.googleapis.com" \
  --format="table(auditConfigs.service,auditConfigs.auditLogConfigs.logType)"
```

---

## Key Takeaways

1. **Assured Workloads ≠ Automatic AI Security**: Platform controls are a foundation, not a complete solution
2. **CMEK is Mandatory**: You must implement customer-managed encryption for all Vertex AI resources
3. **Private by Default**: Never deploy public endpoints or notebooks in production
4. **Model Governance**: Restrict access to approved models via organization policies
5. **Defense in Depth**: Layer controls (CMEK + VPC-SC + IAM + Audit Logs + Input Validation)
6. **AI-Specific Risks**: Traditional security controls don't address prompt injection, model inversion, etc.
7. **Continuous Monitoring**: Use Security Command Center and Cloud Logging for real-time alerts

---

## Resources

- [Vertex AI FedRAMP High Documentation](https://cloud.google.com/vertex-ai/docs/fedramp)
- [Vertex AI Security Best Practices](https://cloud.google.com/vertex-ai/docs/general/security)
- [Assured Workloads Documentation](https://cloud.google.com/assured-workloads/docs)
- [Organization Policy Constraints for Vertex AI](https://cloud.google.com/vertex-ai/docs/training/custom-constraints)
- [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)
- [Security Command Center for Vertex AI](https://cloud.google.com/blog/products/identity-security/introducing-security-command-center-protection-for-vertex-ai)

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-13  
**Compliance Regime**: FedRAMP High / DoD IL5  
**Status**: Production guidance for Vertex AI in Assured Workloads
