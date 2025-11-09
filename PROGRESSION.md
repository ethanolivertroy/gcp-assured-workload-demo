# Compliance Progression: From Vulnerable to FedRAMP High Compliant

This document tracks the incremental remediation of **12 attempted security violations** across 9 commits.

**Key Finding**: Assured Workloads prevented **4 violations** (33%) via organization policies, but allowed **8 violations** (67%) to deploy successfully.

## Violations Prevented by Assured Workloads

Assured Workloads automatically blocked these violations before deployment:

| # | Violation | NIST Controls | Organization Policy Constraint |
|---|-----------|---------------|-------------------------------|
| 9 | Storage without UBLA | AC-3 | `constraints/storage.uniformBucketLevelAccess` |
| 10 | Public bucket access (allUsers IAM) | AC-3 | Customer domain restrictions (412 error) |
| 11 | Service account key creation | IA-5 | `constraints/iam.disableServiceAccountKeyCreation` |
| 12 | Editor/Owner role assignment | AC-6 | IAM policy restrictions (403 errors) |

These violations **could not be deployed** and are marked as ✅ **PREVENTED** in the tracking matrix below.

## Quick Reference

| Commit | Description | Violations Fixed | Violations Remaining | AW Prevented |
|--------|-------------|------------------|---------------------|--------------|
| **Commit 1** | Non-compliant baseline | 0 | 8 | 4 |
| **Commit 2** | GKE compute security | 3 | 5 | 4 |
| **Commit 3** | Data encryption (CMEK) | 1 | 4 | 4 |
| **Commit 4** | IAM and networking | 2 | 2 | 4 |
| **Commit 5** | Audit logging | 1 | 1 | 4 |
| **Commit 6** | Vulnerability management | 1 | 0 | 4 |
| **Commit 7** | DR and backup | 0 | 0 | 4 |
| **Commit 8** | Service mesh and mTLS | 0 | 0 | 4 |
| **Commit 9** | Testing documentation | 0 | 0 | 4 |

---

## Violation Tracking Matrix

### Service-Level Violations (8) - Allowed by Assured Workloads

| # | Violation | NIST Controls | Commit 1 | Commit 2 | Commit 3 | Commit 4 | Commit 5 | Commit 6 | Commit 7 | Commit 8 |
|---|-----------|---------------|----------|----------|----------|----------|----------|----------|----------|----------|
| 1 | Public GKE cluster | SC-7, AC-4 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 2 | No Binary Auth/Workload Identity | CM-7, IA-2, AC-6 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 3 | No GKE secrets CMEK | SC-28, SC-12 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 4 | Cloud SQL public/no CMEK | AC-17, SC-8, SC-28 | 🔴 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 5 | Storage no CMEK | SC-28 | 🔴 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 6 | Missing network controls | SC-7, SC-7(5) | 🔴 | 🔴 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 | 🟢 |
| 7 | Minimal audit logging | AU-2, AU-9, AU-11 | 🔴 | 🔴 | 🔴 | 🔴 | 🟢 | 🟢 | 🟢 | 🟢 |
| 8 | No vulnerability mgmt | SI-2, RA-5 | 🔴 | 🔴 | 🔴 | 🔴 | 🔴 | 🟢 | 🟢 | 🟢 |

### Platform-Level Violations (4) - PREVENTED by Assured Workloads

| # | Violation | NIST Controls | Status |
|---|-----------|---------------|--------|
| 9 | Storage without UBLA | AC-3 | ✅ **PREVENTED** by `constraints/storage.uniformBucketLevelAccess` |
| 10 | Public bucket IAM (allUsers) | AC-3 | ✅ **PREVENTED** by customer domain restrictions (Error 412) |
| 11 | Service account key creation | IA-5 | ✅ **PREVENTED** by `constraints/iam.disableServiceAccountKeyCreation` |
| 12 | Overprivileged Editor role | AC-6 | ✅ **PREVENTED** by IAM policy restrictions (Error 403) |

**Legend**:
- 🔴 **Violated** (allowed by AW, successfully deployed)
- 🟢 **Compliant** (fixed in this commit)
- ✅ **PREVENTED** (blocked by AW organization policies)

---

## Architecture Evolution Diagrams

### Commit 1: Non-Compliant Baseline

```
┌──────────────────────────────────────────────────────────────┐
│  INTERNET (Public Access)                                    │
│  Anyone can access everything!                               │
└────────────┬────────────────────────────┬────────────────────┘
             │                            │
    ┌────────▼────────┐          ┌────────▼──────────┐
    │  Public GKE     │          │  Public Cloud SQL │
    │  Control Plane  │          │  0.0.0.0/0 access │
    │  104.154.x.x    │          │  34.72.x.x        │
    └────────┬────────┘          │  No SSL required  │
             │                   │  No CMEK          │
    ┌────────▼──────────────┐    └───────────────────┘
    │  GKE Nodes (Public)   │
    │  External IPs         │            ┌─────────────────────────┐
    │  Default SA           │            │  GCS Bucket             │
    │  No Binary Auth       │◄───────────┤  PUBLIC (allUsers)      │
    └────────┬──────────────┘            │  No CMEK                │
             │                           │  ✅ UBLA (AW enforced)  │
    ┌────────▼──────────────┐            └─────────────────────────┘
    │  llama.cpp Pod        │
    │  ┌──────────────────┐ │
    │  │ No Auth          │ │
    │  │ No mTLS          │ │
    │  │ ConfigMap secrets│ │
    │  └──────────────────┘ │
    └────────┬──────────────┘
             │
    ┌────────▼──────────────┐
    │  LoadBalancer         │
    │  Type: Public         │
    │  34.134.x.x:80        │
    └───────────────────────┘
             │
    ┌────────▼──────────────┐
    │  INTERNET             │
    │  curl http://IP/v1/   │
    │  NO AUTHENTICATION!   │
    └───────────────────────┘

🔴 VIOLATIONS ALLOWED: 8/12 (67%)
❌ Public cluster, public SQL
❌ No CMEK anywhere
❌ No authentication, no mTLS
❌ No audit logging, no vulnerability scanning

✅ VIOLATIONS PREVENTED: 4/12 (33%)
✅ UBLA enforced by Assured Workloads
✅ Public bucket IAM (allUsers) blocked
✅ Cannot create SA keys (org policy)
✅ Cannot grant Editor role (IAM restrictions)
```

### Commit 2: GKE Security Fixed

```
┌──────────────────────────────────────────────────────────────┐
│  INTERNET (Public Access)                                    │
└────────────┬─────────────────────────────────────────────────┘
             │
    ┌────────▼──────────────────┐
    │  Private GKE Cluster      │
    │  ┌─────────────────────┐  │      ┌─────────────────────┐
    │  │ Control Plane       │  │      │  Public Cloud SQL   │
    │  │ 172.16.0.2 (Private)│  │      │  Still vulnerable!  │
    │  │ Master Auth Networks│  │      │  0.0.0.0/0 access   │
    │  └─────────────────────┘  │      └─────────────────────┘
    │  ┌─────────────────────┐  │
    │  │ Private Nodes       │  │      ┌─────────────────────┐
    │  │ No external IPs     │  │      │  GCS Bucket         │
    │  │ Workload Identity ✅│◄─┼──────┤  Still PUBLIC!      │
    │  │ Binary Auth ✅      │  │      │  Still no CMEK!     │
    │  │ Network Policies ✅ │  │      └─────────────────────┘
    │  │ Secrets CMEK ✅     │  │
    │  └──────────┬──────────┘  │
    │             │              │
    │    ┌────────▼──────────┐  │
    │    │  llama.cpp Pod    │  │
    │    │  (Still public LB)│  │
    │    └───────────────────┘  │
    └──────────────────────┬────┘
                           │
                  ┌────────▼──────────┐
                  │  LoadBalancer     │
                  │  Still PUBLIC     │
                  │  34.134.x.x:80    │
                  └───────────────────┘

🟢 FIXED: 3/10 (GKE cluster, Binary Auth, Workload Identity)
🔴 REMAINING: 7/10 (SQL, Storage, IAM, Network, Logging, Vuln, LLM endpoint)
```

### Commit 3: Data Encryption (CMEK) Fixed

```
┌──────────────────────────────────────────────────────────────┐
│  INTERNET (Still has some public access)                     │
└────────────┬─────────────────────────────────────────────────┘
             │
    ┌────────▼──────────────────┐
    │  Private GKE Cluster ✅   │
    │  ┌─────────────────────┐  │      ┌─────────────────────┐
    │  │ Control Plane       │  │      │  Cloud SQL ✅       │
    │  │ Private + CMEK ✅   │  │      │  Private IP only    │
    │  └─────────────────────┘  │      │  SSL required ✅    │
    │  ┌─────────────────────┐  │      │  CMEK encryption ✅ │
    │  │ Private Nodes       │  │      │  VPC Peering        │
    │  │ Workload Identity ✅│  │      └─────────────────────┘
    │  │ Binary Auth ✅      │  │
    │  │ Secrets CMEK ✅     │  │      ┌─────────────────────┐
    │  └──────────┬──────────┘  │      │  GCS Bucket ✅      │
    │             │              │◄─────┤  Private (no public)│
    │    ┌────────▼──────────┐  │      │  CMEK encryption ✅ │
    │    │  llama.cpp Pod    │  │      │  UBLA enabled ✅    │
    │    │  (Still public LB)│  │      │  Public access      │
    │    └───────────────────┘  │      │  prevention ✅      │
    └──────────────────────┬────┘      └─────────────────────┘
                           │
                  ┌────────▼──────────┐
                  │  LoadBalancer     │
                  │  Still PUBLIC     │
                  │  (Will fix in C8) │
                  └───────────────────┘

🟢 FIXED: 5/10 (+ Cloud SQL CMEK, + Storage CMEK/UBLA)
🔴 REMAINING: 5/10 (IAM, Network, Logging, Vuln, LLM endpoint)
```

### Commit 4: IAM & Networking Fixed

```
┌──────────────────────────────────────────────────────────────┐
│  VPC Service Controls Perimeter                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Private VPC Network ✅                                │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │ Subnet (Private Google Access ✅)                │  │  │
│  │  │ VPC Flow Logs enabled ✅                         │  │  │
│  │  │ Default-DENY firewall rules ✅                   │  │  │
│  │  └────────┬─────────────────────────────────────────┘  │  │
│  │           │                                             │  │
│  │  ┌────────▼──────────────────┐                         │  │
│  │  │  Private GKE Cluster ✅   │                         │  │
│  │  │  ┌─────────────────────┐  │      ┌───────────────┐ │  │
│  │  │  │ Control Plane       │  │      │  Cloud SQL ✅ │ │  │
│  │  │  │ Private + CMEK ✅   │  │      │  Private IP   │ │  │
│  │  │  └─────────────────────┘  │      │  SSL + CMEK ✅│ │  │
│  │  │  ┌─────────────────────┐  │      └───────────────┘ │  │
│  │  │  │ Nodes               │  │                         │  │
│  │  │  │ Workload Identity ✅│  │      ┌───────────────┐ │  │
│  │  │  │ Least-privilege SA ✅│◄─┼──────┤  GCS Bucket ✅│ │  │
│  │  │  │ (No SA keys!) ✅    │  │      │  Private      │ │  │
│  │  │  └──────────┬──────────┘  │      │  CMEK + UBLA ✅│ │  │
│  │  │             │              │      └───────────────┘ │  │
│  │  │    ┌────────▼──────────┐  │                         │  │
│  │  │    │  llama.cpp Pod    │  │                         │  │
│  │  │    │  (Still public LB)│  │                         │  │
│  │  │    └───────────────────┘  │                         │  │
│  │  └──────────────────────┬────┘                         │  │
│  └─────────────────────────┼──────────────────────────────┘  │
│                            │                                  │
└────────────────────────────┼──────────────────────────────────┘
                             │
                    ┌────────▼──────────┐
                    │  LoadBalancer     │
                    │  Still PUBLIC     │
                    │  (Last to fix)    │
                    └───────────────────┘

🟢 FIXED: 7/10 (+ Least-privilege IAM, + VPC-SC, + Network controls)
🔴 REMAINING: 3/10 (Logging, Vulnerability mgmt, LLM endpoint)
```

### Commit 8: Fully Compliant (Service Mesh + mTLS)

```
┌──────────────────────────────────────────────────────────────┐
│  VPC Service Controls Perimeter (All traffic controlled)    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Private VPC Network ✅                                │  │
│  │  (Private Google Access, Flow Logs, Firewall Rules)   │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Private GKE Cluster (Fully Hardened) ✅         │  │  │
│  │  │  ┌────────────────────────────────────────────┐  │  │  │
│  │  │  │ Control Plane (Private, CMEK) ✅           │  │  │  │
│  │  │  │ Binary Authorization ✅                    │  │  │  │
│  │  │  │ Workload Identity ✅                       │  │  │  │
│  │  │  │ Network Policies ✅                        │  │  │  │
│  │  │  │ Vulnerability Scanning ✅                  │  │  │  │
│  │  │  │ Auto-upgrades ✅                           │  │  │  │
│  │  │  └────────────────────────────────────────────┘  │  │  │
│  │  │  ┌────────────────────────────────────────────┐  │  │  │
│  │  │  │ Istio Service Mesh (Fleet + mTLS) ✅      │  │  │  │
│  │  │  │ ┌──────────────────────────────────────┐  │  │  │  │
│  │  │  │ │ Namespace: llama-demo                │  │  │  │  │
│  │  │  │ │ Sidecar injection: enabled ✅        │  │  │  │  │
│  │  │  │ │ PeerAuthentication: STRICT ✅        │  │  │  │  │
│  │  │  │ │                                      │  │  │  │  │
│  │  │  │ │ ┌────────────────────────────────┐  │  │  │  │  │
│  │  │  │ │ │ llama.cpp Pod                  │  │  │  │  │  │
│  │  │  │ │ │ ┌────────────┐  ┌────────────┐ │  │  │  │  │  │
│  │  │  │ │ │ │ App        │  │ Envoy      │ │  │  │  │  │  │
│  │  │  │ │ │ │ Container  │◄─┤ Sidecar    │ │  │  │  │  │  │
│  │  │  │ │ │ │ + API key  │  │ (mTLS) ✅  │ │  │  │  │  │  │
│  │  │  │ │ │ └────────────┘  └────────────┘ │  │  │  │  │  │
│  │  │  │ │ │ Workload Identity SA ✅        │  │  │  │  │  │
│  │  │  │ │ │ Secret Manager integration ✅  │  │  │  │  │  │
│  │  │  │ │ └────────────────────────────────┘  │  │  │  │  │
│  │  │  │ └──────────────┬───────────────────────┘  │  │  │  │
│  │  │  │                │                           │  │  │  │
│  │  │  │    ┌───────────▼───────────────┐          │  │  │  │
│  │  │  │    │ Service: ClusterIP ONLY ✅│          │  │  │  │
│  │  │  │    │ (No public LoadBalancer)  │          │  │  │  │
│  │  │  │    └───────────┬───────────────┘          │  │  │  │
│  │  │  │                │                           │  │  │  │
│  │  │  │    ┌───────────▼───────────────┐          │  │  │  │
│  │  │  │    │ Istio Ingress Gateway     │          │  │  │  │
│  │  │  │    │ (Internal only, mTLS) ✅  │          │  │  │  │
│  │  │  │    └───────────────────────────┘          │  │  │  │
│  │  │  └────────────────────────────────────────────┘  │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌────────────────────────────────────────────┐  │  │  │
│  │  │  │ Cloud SQL (Private, CMEK, SSL) ✅         │  │  │  │
│  │  │  │ PITR + Cross-region replica ✅            │  │  │  │
│  │  │  │ 365-day backup retention ✅               │  │  │  │
│  │  │  └────────────────────────────────────────────┘  │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌────────────────────────────────────────────┐  │  │  │
│  │  │  │ GCS Bucket (Private, CMEK, UBLA) ✅       │  │  │  │
│  │  │  │ Versioning + Lifecycle policies ✅        │  │  │  │
│  │  │  └────────────────────────────────────────────┘  │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ Cloud Audit Logs (Comprehensive) ✅                     │  │
│  │ - All log types enabled (ADMIN, DATA_READ, DATA_WRITE) │  │
│  │ - 365-day retention (locked) ✅                         │  │
│  │ - CMEK encryption ✅                                    │  │
│  │ - 7-year archive bucket ✅                              │  │
│  └─────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘

               NO PUBLIC ACCESS ANYWHERE ✅
               ALL DATA ENCRYPTED WITH CMEK ✅
               mTLS ENFORCED EVERYWHERE ✅
               COMPREHENSIVE AUDIT LOGGING ✅
               ZERO-TRUST ARCHITECTURE ✅

🟢 COMPLIANT: 10/10 violations remediated
✅ FedRAMP High / DoD IL5 ready
```

---

## Detailed Commit Breakdown

### Commit 1: Non-Compliant Baseline

**Purpose**: Demonstrate all 10 violations within an Assured Workloads environment

**What's Deployed**:
- Public GKE cluster (no private nodes/endpoint)
- Cloud SQL with public IP (0.0.0.0/0), no SSL, no CMEK
- GCS bucket publicly accessible (allUsers), no CMEK, no UBLA
- Overprivileged service account (Editor role) with long-lived keys
- No VPC Service Controls, no Private Google Access
- Minimal audit logging (30-day retention, no Data Access logs, no CMEK)
- No vulnerability scanning, no auto-upgrades
- llama.cpp exposed via public LoadBalancer, no authentication, no mTLS

**How to Test**:
```bash
# Run the violations check script
./check-violations.sh

# Manual tests
curl https://$(terraform output -raw cluster_endpoint)/version
curl http://$(kubectl get svc llama-server -n llama-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/v1/models
gsutil ls gs://$(terraform output -raw bucket_name)
```

**Expected Result**: All 10 violations detected ❌

---

### Commit 2: GKE Compute Security

**Fixes Applied**:
1. ✅ Private GKE cluster (private nodes + private endpoint)
2. ✅ Binary Authorization enabled with attestation policy
3. ✅ Workload Identity configured
4. ✅ Application-layer secrets encryption (CMEK for etcd)
5. ✅ Network policies enabled

**Code Changes**:
- Add `private_cluster_config` block
- Configure `workload_identity_config`
- Enable `binary_authorization`
- Add `database_encryption` with KMS key
- Enable `network_policy`

**Validation**:
```bash
# Verify private cluster
gcloud container clusters describe CLUSTER --format="get(privateClusterConfig)"

# Verify Binary Authorization
gcloud container binauthz policy export

# Verify Workload Identity
gcloud container clusters describe CLUSTER --format="get(workloadIdentityConfig)"
```

**Status**: 3/10 fixed | 7/10 remaining

---

### Commit 3: Data Encryption (CMEK)

**Fixes Applied**:
1. ✅ Cloud SQL: Private IP only (VPC peering), SSL required, CMEK encryption
2. ✅ GCS: CMEK encryption, UBLA enabled, public access prevention

**Code Changes**:
- Remove Cloud SQL `ipv4_enabled`, add `private_network`
- Set `require_ssl = true`
- Add `encryption_key_name` to Cloud SQL
- Add `encryption` block to GCS bucket
- Enable `uniform_bucket_level_access`
- Add `public_access_prevention = "enforced"`
- Remove public IAM binding (allUsers)

**Validation**:
```bash
# Verify SQL private IP
gcloud sql instances describe INSTANCE --format="get(ipAddresses)"

# Verify GCS CMEK
gcloud storage buckets describe gs://BUCKET --format="get(encryption)"

# Verify UBLA
gsutil uniformbucketlevelaccess get gs://BUCKET
```

**Status**: 5/10 fixed | 5/10 remaining

---

### Commit 4: IAM and Networking

**Fixes Applied**:
1. ✅ Replace Editor role with granular permissions (least privilege)
2. ✅ Remove service account keys, use Workload Identity exclusively
3. ✅ Enable Private Google Access on subnets
4. ✅ Add default-deny firewall rules
5. ✅ Enable VPC Flow Logs
6. ✅ Configure VPC Service Controls perimeter

**Code Changes**:
- Remove `google_project_iam_member` with Editor role
- Add specific role bindings (logging.logWriter, storage.objectViewer, etc.)
- Remove `google_service_account_key` resource
- Set `private_ip_google_access = true`
- Add `google_compute_firewall` with deny-all rule
- Add `log_config` to subnet for Flow Logs
- Add `google_access_context_manager_service_perimeter`

**Validation**:
```bash
# Verify IAM roles
gcloud projects get-iam-policy PROJECT | grep serviceAccount:SA_EMAIL

# Verify Private Google Access
gcloud compute networks subnets describe SUBNET --format="get(privateIpGoogleAccess)"

# Verify firewall rules
gcloud compute firewall-rules list --filter="action=DENY"
```

**Status**: 7/10 fixed | 3/10 remaining

---

### Commit 5: Audit Logging

**Fixes Applied**:
1. ✅ Enable all audit log types (ADMIN_READ, DATA_READ, DATA_WRITE)
2. ✅ Extend retention to 365 days with locked policy
3. ✅ Add CMEK encryption for logs
4. ✅ Create audit log archive bucket (7-year retention)
5. ✅ Configure log sink for long-term archival

**Code Changes**:
- Add `google_project_iam_audit_config` for all services
- Update `google_logging_project_bucket_config` with 365-day retention
- Set `locked = true` for immutable retention
- Add `cmek_settings` for log encryption
- Create dedicated audit archive bucket
- Add `google_logging_project_sink`

**Validation**:
```bash
# Verify audit log configuration
gcloud projects get-iam-policy PROJECT

# Verify log retention
gcloud logging buckets describe BUCKET

# Verify log sink
gcloud logging sinks list
```

**Status**: 8/10 fixed | 2/10 remaining

---

### Commit 6: Vulnerability Management

**Fixes Applied**:
1. ✅ Enable GKE Security Posture and vulnerability scanning
2. ✅ Configure automatic node repairs and upgrades
3. ✅ Set release channel for managed updates
4. ✅ Configure maintenance windows

**Code Changes**:
- Add `security_posture_config` to cluster
- Enable `workload_vulnerability_config`
- Set `release_channel` to REGULAR
- Configure `maintenance_policy`
- Set node pool `management` auto-repair and auto-upgrade

**Validation**:
```bash
# Verify security posture
gcloud container clusters describe CLUSTER --format="get(securityPostureConfig)"

# Verify auto-upgrades
gcloud container node-pools describe POOL --cluster=CLUSTER --format="get(management)"
```

**Status**: 9/10 fixed | 1/10 remaining

---

### Commit 7: Disaster Recovery and Backup

**Enhancements** (no new violations fixed, but strengthens existing controls):
- Enable Cloud SQL Point-in-Time Recovery (PITR)
- Extend backup retention to 365 days
- Add cross-region read replica with CMEK
- Enable Storage versioning
- Configure backup encryption with CMEK

**Code Changes**:
- Set `point_in_time_recovery_enabled = true`
- Update `backup_retention_settings` to 365 days
- Add `google_sql_database_instance` replica in different region
- Enable `versioning` on storage bucket
- Add lifecycle rules for version cleanup

**Status**: 9/10 fixed | 1/10 remaining (Commit 7 doesn't fix violations, adds DR)

---

### Commit 8: Service Mesh and mTLS

**Fixes Applied**:
1. ✅ Register GKE cluster to Fleet
2. ✅ Enable Service Mesh (Istio)
3. ✅ Deploy PeerAuthentication with STRICT mTLS
4. ✅ Change llama.cpp from LoadBalancer to ClusterIP (no public access)
5. ✅ Add API key authentication from Secret Manager
6. ✅ Enable sidecar injection on namespace

**Code Changes**:
- Add `google_gke_hub_membership`
- Enable `google_gke_hub_feature` for Service Mesh
- Deploy Istio `PeerAuthentication` with STRICT mode
- Deploy `DestinationRule` for mTLS
- Change service type from LoadBalancer to ClusterIP
- Move API key to Secret Manager
- Add Istio Ingress Gateway (internal only)

**Validation**:
```bash
# Verify mTLS
istioctl authn tls-check POD SERVICE

# Verify no public LoadBalancer
kubectl get svc -n llama-demo

# Verify API key in Secret Manager
gcloud secrets versions access latest --secret=llama-api-key
```

**Status**: 10/10 fixed | 0/10 remaining ✅

---

### Commit 9: Testing Documentation

**Deliverable**: TESTS.md with comprehensive validation commands

**Contents**:
- Before/after tests for each violation
- NIST control validation steps
- istioctl commands for mTLS verification
- Security scanning validation
- Compliance check procedures

**No infrastructure changes** - documentation only

---

## Summary

This progression demonstrates that **Google Assured Workloads provides a foundation but requires deliberate configuration** to achieve FedRAMP High / DoD IL5 compliance. Each commit systematically addresses violation categories, showing the gap between platform-level controls and service-level security.

**Key Insight**: All 10 violations can exist within an Assured Workloads environment. True compliance requires defense-in-depth, automation, and continuous monitoring.
