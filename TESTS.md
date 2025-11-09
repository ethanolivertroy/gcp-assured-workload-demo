# Compliance Validation Tests

This document provides executable tests to validate FedRAMP High / DoD IL5 compliance for the GKE cluster and supporting infrastructure.

**Current State (Commit 1)**: 4/12 controls enforced (33% compliant)
- ✅ 4 violations **PREVENTED** by Assured Workloads
- ❌ 8 violations **ALLOWED** (require manual configuration)

## Prerequisites

```bash
export PROJECT_ID="real-slim-shady-fedramp-high"
export REGION="us-central1"
export ZONE="us-central1-a"
export CLUSTER="non-compliant-cluster"

# Authenticate
gcloud auth login
gcloud config set project $PROJECT_ID
gcloud container clusters get-credentials $CLUSTER --zone=$ZONE
```

---

## Section A: Platform-Level Controls (Assured Workloads Enforcement)

### ✅ Test 1: UBLA Enforcement on Storage Buckets
**NIST Control**: AC-3 (Access Enforcement)
**Risk**: LOW (prevented by AW)
**Status**: PASS

```bash
# Test: Attempt to create bucket without UBLA
gcloud storage buckets create gs://test-no-ubla-$PROJECT_ID \
  --location=$REGION \
  --no-uniform-bucket-level-access

# Expected: Error 412: Request violates constraint 'constraints/storage.uniformBucketLevelAccess'
```

**Validation**:
```bash
# Verify existing bucket has UBLA enabled
gsutil ubla get gs://$PROJECT_ID-llama-models-non-compliant
# Expected: Uniform bucket-level access setting for gs://...: Enabled
```

---

### ✅ Test 2: Public Bucket IAM Blocked (allUsers)
**NIST Control**: AC-3 (Access Enforcement)
**Risk**: CRITICAL (prevented by AW)
**Status**: PASS

```bash
# Test: Attempt to grant allUsers access
gsutil iam ch allUsers:objectViewer gs://$PROJECT_ID-llama-models-non-compliant

# Expected: Error 412: One or more users named in the policy do not belong to a permitted customer.
```

**Validation**:
```bash
# Verify no public access
gsutil iam get gs://$PROJECT_ID-llama-models-non-compliant | grep allUsers
# Expected: No output (allUsers not in IAM policy)
```

---

### ✅ Test 3: Service Account Key Creation Blocked
**NIST Control**: IA-5 (Authenticator Management)
**Risk**: HIGH (prevented by AW)
**Status**: PASS

```bash
# Test: Attempt to create SA key
gcloud iam service-accounts keys create key.json \
  --iam-account=overprivileged-sa@$PROJECT_ID.iam.gserviceaccount.com

# Expected: Error: constraints/iam.disableServiceAccountKeyCreation
```

---

### ✅ Test 4: Overprivileged Role Assignment Blocked
**NIST Control**: AC-6 (Least Privilege)
**Risk**: CRITICAL (prevented by AW)
**Status**: PASS

```bash
# Test: Attempt to grant Editor role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:overprivileged-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Expected: Error 403: Policy update access denied.
```

---

## Section B: GKE Cluster Security (NIST SC-7, AC-4)

### ❌ Test 5: Public GKE Cluster Endpoint
**NIST Control**: SC-7 (Boundary Protection), SC-7(4), SC-7(5)
**Risk**: CRITICAL
**Status**: **FAIL** - Public cluster deployed

```bash
# Check if cluster has private endpoint
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(privateClusterConfig.enablePrivateEndpoint)"

# Expected (Non-Compliant): Empty/null or False
# Expected (Compliant - Commit 2): True
```

**Remediation**: Commit 2 - Enable private cluster configuration

---

### ❌ Test 6: Nodes with External IPs
**NIST Control**: SC-7 (Boundary Protection)
**Risk**: CRITICAL
**Status**: **FAIL** - Nodes have public IPs

```bash
# Check if nodes have external IPs
gcloud compute instances list --filter="name:gke-non-compliant-cluster" \
  --format="table(name,networkInterfaces[0].accessConfigs[0].natIP)"

# Expected (Non-Compliant): External IPs shown
# Expected (Compliant - Commit 2): No output (no external IPs)
```

**Remediation**: Commit 2 - Enable private nodes

---

### ❌ Test 7: Network Policy Disabled
**NIST Control**: SC-7(5) (Deny by Default)
**Risk**: HIGH
**Status**: **FAIL** - No micro-segmentation

```bash
# Check if network policy enabled
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(networkPolicy.enabled)"

# Expected (Non-Compliant): False
# Expected (Compliant - Commit 2): True
```

**Remediation**: Commit 2 - Enable network policies

---

## Section C: FIPS 140-2 Encryption (NIST SC-13, SC-28, SC-12)

### ❌ Test 8: GKE Secrets Encryption (CMEK for etcd)
**NIST Control**: SC-28 (Protection at Rest), SC-12 (Cryptographic Key Establishment)
**Risk**: HIGH
**Status**: **FAIL** - No CMEK for Kubernetes secrets

```bash
# Check if CMEK enabled for application-layer secrets
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(databaseEncryption.state)"

# Expected (Non-Compliant): DECRYPTED (Google-managed keys only)
# Expected (Compliant - Commit 2): ENCRYPTED
```

**FIPS 140-2 Compliance Check**:
```bash
# Verify platform uses FIPS 140-2 validated modules
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(nodeConfig.bootDiskKmsKey)"

# Note: Google Cloud Platform encryption is FIPS 140-2 validated at platform level
# CMEK adds customer control over key management
```

**Remediation**: Commit 2 - Configure database encryption with CMEK

---

### ❌ Test 9: Cloud SQL CMEK Encryption
**NIST Control**: SC-28, SC-12
**Risk**: HIGH
**Status**: **FAIL** - Google-managed keys only

```bash
# Check if Cloud SQL uses CMEK
gcloud sql instances describe non-compliant-sql \
  --format="get(diskEncryptionConfiguration.kmsKeyName)"

# Expected (Non-Compliant): Empty (Google-managed encryption)
# Expected (Compliant - Commit 3): projects/.../cryptoKeys/...
```

**Remediation**: Commit 3 - Add CMEK for Cloud SQL

---

### ❌ Test 10: Storage CMEK Encryption
**NIST Control**: SC-28, SC-12
**Risk**: HIGH
**Status**: **FAIL** - Google-managed keys only

```bash
# Check if GCS bucket uses CMEK
gsutil encryption get gs://$PROJECT_ID-llama-models-non-compliant

# Expected (Non-Compliant): "Default encryption"
# Expected (Compliant - Commit 3): "Encryption key: projects/.../cryptoKeys/..."
```

**Remediation**: Commit 3 - Add CMEK for GCS buckets

---

## Section D: Binary Authorization (NIST CM-7, SI-7)

### ❌ Test 11: Binary Authorization Policy
**NIST Control**: CM-7 (Least Functionality), SI-7 (Software Integrity)
**Risk**: MEDIUM
**Status**: **FAIL** - No image signature enforcement

```bash
# Check Binary Authorization status
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(binaryAuthorization.evaluationMode)"

# Expected (Non-Compliant): DISABLED
# Expected (Compliant - Commit 2): PROJECT_SINGLETON_POLICY_ENFORCE
```

**Image Signature Validation**:
```bash
# Check if attestors configured
gcloud container binauthz attestors list

# Expected (Non-Compliant): No attestors
# Expected (Compliant - Commit 2): attestors/build-attestor listed
```

**Remediation**: Commit 2 - Enable Binary Authorization with attestation

---

## Section E: Workload Identity (NIST IA-2, AC-6)

### ❌ Test 12: Workload Identity Configuration
**NIST Control**: IA-2 (Identification and Authentication), AC-6 (Least Privilege)
**Risk**: HIGH
**Status**: **FAIL** - Using default service accounts

```bash
# Check if Workload Identity enabled on cluster
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(workloadIdentityConfig.workloadPool)"

# Expected (Non-Compliant): Empty/null
# Expected (Compliant - Commit 2): PROJECT_ID.svc.id.goog
```

**Node Pool Workload Metadata Config**:
```bash
# Check node pool configuration
gcloud container node-pools describe non-compliant-node-pool \
  --cluster=$CLUSTER --zone=$ZONE \
  --format="get(config.workloadMetadataConfig.mode)"

# Expected (Non-Compliant): Empty or GCE_METADATA
# Expected (Compliant - Commit 2): GKE_METADATA
```

**Remediation**: Commit 2 - Enable Workload Identity

---

## Section F: mTLS & Service Mesh (NIST SC-8, SC-23)

### ❌ Test 13: Service Mesh Installation
**NIST Control**: SC-8 (Transmission Confidentiality), SC-23 (Session Authenticity)
**Risk**: CRITICAL
**Status**: **FAIL** - No service mesh deployed

```bash
# Check if cluster registered to Fleet (required for service mesh)
gcloud container fleet memberships list --project=$PROJECT_ID

# Expected (Non-Compliant): Empty (no fleet membership)
# Expected (Compliant - Commit 8): Cluster registered
```

**Service Mesh Status**:
```bash
# Check if Istio installed
kubectl get namespace istio-system

# Expected (Non-Compliant): Error: namespace "istio-system" not found
# Expected (Compliant - Commit 8): Active namespace
```

**Remediation**: Commit 8 - Deploy Istio service mesh

---

### ❌ Test 14: mTLS Policy Enforcement
**NIST Control**: SC-8 (Transmission Confidentiality)
**Risk**: CRITICAL
**Status**: **FAIL** - No mTLS enforcement

```bash
# Check for STRICT mTLS policy
kubectl get peerauthentication -A -o yaml | grep "mode: STRICT"

# Expected (Non-Compliant): No output (no PeerAuthentication)
# Expected (Compliant - Commit 8): mode: STRICT
```

**mTLS Verification** (Post-Deployment):
```bash
# Verify mTLS between services
istioctl authn tls-check llama-server-POD.llama-demo llama-server.llama-demo.svc.cluster.local

# Expected (Compliant - Commit 8):
# HOST:PORT                                     STATUS     SERVER     CLIENT
# llama-server.llama-demo.svc.cluster.local     SUCCESS    mTLS       mTLS
```

**Remediation**: Commit 8 - Configure STRICT mTLS policy

---

## Section G: Pod Security Standards (NIST AC-6, CM-7)

### ❌ Test 15: Security Context Configuration
**NIST Control**: AC-6 (Least Privilege), CM-7 (Least Functionality)
**Risk**: MEDIUM
**Status**: **FAIL** - No security contexts defined

```bash
# Check pod security contexts (example: llama-server if deployed)
kubectl get deployment -n llama-demo llama-server -o yaml | grep -A 20 "securityContext:"

# Expected (Non-Compliant): No securityContext or minimal settings
# Expected (Compliant - Commit 2):
#   runAsNonRoot: true
#   readOnlyRootFilesystem: true
#   allowPrivilegeEscalation: false
#   capabilities:
#     drop: ["ALL"]
```

**Pod Security Admission**:
```bash
# Check namespace labels for Pod Security Standards
kubectl get namespace llama-demo -o yaml | grep "pod-security"

# Expected (Compliant - Commit 2):
# pod-security.kubernetes.io/enforce: restricted
# pod-security.kubernetes.io/audit: restricted
# pod-security.kubernetes.io/warn: restricted
```

**Remediation**: Commit 2 - Add security contexts to all pods

---

## Section H: Vulnerability Management (NIST SI-2, RA-5)

### ❌ Test 16: Container Vulnerability Scanning
**NIST Control**: SI-2 (Flaw Remediation), RA-5 (Vulnerability Monitoring and Scanning)
**Risk**: HIGH
**Status**: **FAIL** - No scanning enabled

```bash
# Check if vulnerability scanning enabled
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(securityPostureConfig.vulnerabilityMode)"

# Expected (Non-Compliant): Empty/DISABLED
# Expected (Compliant - Commit 6): VULNERABILITY_ENTERPRISE or VULNERABILITY_BASIC
```

**Workload Vulnerability Scanning**:
```bash
# Check security posture
gcloud container clusters describe $CLUSTER --zone=$ZONE \
  --format="get(securityPostureConfig.mode)"

# Expected (Non-Compliant): Empty/DISABLED
# Expected (Compliant - Commit 6): BASIC or ENTERPRISE
```

**Remediation**: Commit 6 - Enable vulnerability scanning

---

### ❌ Test 17: Node Auto-Repair and Auto-Upgrade
**NIST Control**: SI-2 (Flaw Remediation)
**Risk**: MEDIUM
**Status**: **PARTIAL FAIL** - Auto-upgrade enabled, auto-repair disabled

```bash
# Check node pool management settings
gcloud container node-pools describe non-compliant-node-pool \
  --cluster=$CLUSTER --zone=$ZONE \
  --format="get(management)"

# Expected (Non-Compliant): autoRepair: false, autoUpgrade: true (partial)
# Expected (Compliant - Commit 6): autoRepair: true, autoUpgrade: true
```

**Remediation**: Commit 6 - Enable auto-repair

---

## Section I: Network Security (NIST SC-7(5), SC-7(8))

### ❌ Test 18: VPC Service Controls
**NIST Control**: SC-7(8) (Route Traffic to Authenticated Proxy Servers)
**Risk**: CRITICAL
**Status**: **FAIL** - No VPC-SC perimeter

```bash
# Check for VPC Service Controls perimeter
gcloud access-context-manager perimeters list --policy=$(gcloud access-context-manager policies list --format="value(name)")

# Expected (Non-Compliant): Empty (no perimeter)
# Expected (Compliant - Commit 4): Perimeter with GCS, GKE resources
```

**Remediation**: Commit 4 - Create VPC Service Controls perimeter

---

### ❌ Test 19: Private Google Access
**NIST Control**: SC-7 (Boundary Protection)
**Risk**: HIGH
**Status**: **FAIL** - Disabled on subnets

```bash
# Check Private Google Access on subnet
gcloud compute networks subnets describe demo-subnet \
  --region=$REGION \
  --format="get(privateIpGoogleAccess)"

# Expected (Non-Compliant): False
# Expected (Compliant - Commit 4): True
```

**Remediation**: Commit 4 - Enable Private Google Access

---

### ❌ Test 20: Default-Deny Firewall Rules
**NIST Control**: SC-7(5) (Deny by Default)
**Risk**: HIGH
**Status**: **FAIL** - No explicit deny rules

```bash
# Check for default-deny egress rule
gcloud compute firewall-rules list --filter="network:demo-vpc AND direction:EGRESS AND action:DENY" \
  --format="table(name,direction,action,priority)"

# Expected (Non-Compliant): No deny rules
# Expected (Compliant - Commit 4): deny-all-egress rule with priority 65535
```

**Remediation**: Commit 4 - Add default-deny firewall rules

---

### ❌ Test 21: VPC Flow Logs
**NIST Control**: AU-2 (Event Logging), AU-6 (Audit Review)
**Risk**: MEDIUM
**Status**: **FAIL** - No flow logs

```bash
# Check if VPC Flow Logs enabled
gcloud compute networks subnets describe demo-subnet \
  --region=$REGION \
  --format="get(enableFlowLogs)"

# Expected (Non-Compliant): False or empty
# Expected (Compliant - Commit 4): True
```

**Remediation**: Commit 4 - Enable VPC Flow Logs

---

## Section J: Audit & Monitoring (NIST AU-2, AU-6, AU-9, AU-11)

### ❌ Test 22: Data Access Logs
**NIST Control**: AU-2 (Event Logging)
**Risk**: CRITICAL
**Status**: **FAIL** - Data Access logs disabled

```bash
# Check if Data Access logs enabled for GCS
gcloud logging read "protoPayload.serviceName=storage.googleapis.com AND protoPayload.methodName:storage.objects" \
  --limit=1 --format=json

# Expected (Non-Compliant): Empty (no DATA_READ/DATA_WRITE logs)
# Expected (Compliant - Commit 5): Log entries returned
```

**Remediation**: Commit 5 - Enable Data Access logs for all services

---

### ❌ Test 23: Log Retention Period
**NIST Control**: AU-11 (Audit Record Retention)
**Risk**: HIGH
**Status**: **FAIL** - Only 30-day retention

```bash
# Check log bucket retention
gcloud logging buckets describe _Default --location=global \
  --format="get(retentionDays)"

# Expected (Non-Compliant): 30 (default)
# Expected (Compliant - Commit 5): 365 or greater
```

**Remediation**: Commit 5 - Extend retention to 365+ days

---

### ❌ Test 24: Log Encryption (CMEK)
**NIST Control**: AU-9 (Protection of Audit Information)
**Risk**: MEDIUM
**Status**: **FAIL** - Google-managed keys only

```bash
# Check if log bucket uses CMEK
gcloud logging buckets describe _Default --location=global \
  --format="get(cmekSettings.kmsKeyName)"

# Expected (Non-Compliant): Empty (Google-managed encryption)
# Expected (Compliant - Commit 5): projects/.../cryptoKeys/log-key
```

**Remediation**: Commit 5 - Add CMEK for log buckets

---

## Section K: Cloud SQL Security (NIST AC-17, SC-8)

### ❌ Test 25: Cloud SQL Public IP
**NIST Control**: AC-17 (Remote Access)
**Risk**: CRITICAL
**Status**: **FAIL** - Public IP enabled with 0.0.0.0/0

```bash
# Check Cloud SQL IP configuration
gcloud sql instances describe non-compliant-sql \
  --format="get(ipAddresses)"

# Expected (Non-Compliant): Public IP with 0.0.0.0/0 authorized network
# Expected (Compliant - Commit 3): Private IP only
```

**Remediation**: Commit 3 - Disable public IP, use Private Service Connect

---

### ❌ Test 26: Cloud SQL SSL Requirement
**NIST Control**: SC-8 (Transmission Confidentiality)
**Risk**: CRITICAL
**Status**: **FAIL** - SSL not required

```bash
# Check if SSL required
gcloud sql instances describe non-compliant-sql \
  --format="get(settings.ipConfiguration.requireSsl)"

# Expected (Non-Compliant): False
# Expected (Compliant - Commit 3): True
```

**Remediation**: Commit 3 - Require SSL/TLS for all connections

---

## Compliance Score Summary

**Current State (Commit 1)**:
- Total Tests: 26
- ✅ Passed: 4 (15%) - Assured Workloads enforcement
- ❌ Failed: 22 (85%) - Require manual configuration
- **Compliance Score**: 15% (4/26 tests)

**Target State (Commit 8)**:
- ✅ Passed: 26 (100%)
- **Compliance Score**: 100%

---

## Running All Tests

**Automated validation**:
```bash
# Run comprehensive validation script
./validate-state.sh

# Generate compliance report
./validate-state.sh --report compliance-report-$(date +%Y%m%d).json
```

**Manual validation**:
```bash
# Copy each test command and verify results match expected outputs
# Document findings in compliance assessment
```

---

## Evidence Collection for Audits

For each test, collect evidence:

1. **Screenshots** of command output
2. **JSON exports** of resource configurations
3. **Compliance report** from validate-state.sh
4. **Dated documentation** of findings
5. **Remediation plan** mapped to commits

**Example**:
```bash
# Export cluster configuration for audit
gcloud container clusters describe $CLUSTER --zone=$ZONE > evidence/cluster-config-$(date +%Y%m%d).yaml

# Export IAM policies
gcloud projects get-iam-policy $PROJECT_ID > evidence/iam-policy-$(date +%Y%m%d).yaml

# Export audit logs
gcloud logging read "timestamp>=\"2024-01-01\"" --limit=1000 > evidence/audit-logs-$(date +%Y%m%d).json
```

---

## References

- [NIST 800-53 Rev 5](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf)
- [DoD Cloud Computing SRG](https://dl.dod.cyber.mil/wp-content/uploads/cloud/SRG/index.html)
- [FedRAMP High Baseline](https://www.fedramp.gov/assets/resources/documents/FedRAMP_Security_Controls_Baseline.xlsx)
- [GKE Hardening Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [FIPS 140-2 Validated Modules](https://cloud.google.com/docs/security/encryption-in-transit/compliance)
