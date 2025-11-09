# ============================================================================
# COMMIT 1: NON-COMPLIANT BASELINE - ALL 10 FEDRAMP/IL5 VIOLATIONS
# ============================================================================
# This configuration intentionally violates FedRAMP High and DoD IL5 controls
# to demonstrate what Assured Workloads does NOT prevent.
# ============================================================================

# Enable required GCP services
resource "google_project_service" "services" {
  for_each = toset([
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "compute.googleapis.com",
    "binaryauthorization.googleapis.com",
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# ============================================================================
# VIOLATION #7: Network - No VPC Service Controls, No Private Google Access
# NIST SC-7 (Boundary Protection), SC-7(5) (Deny by Default)
# ============================================================================

resource "google_compute_network" "demo_vpc" {
  name                    = "demo-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

resource "google_compute_subnetwork" "demo_subnet" {
  name          = "demo-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.demo_vpc.id

  # VIOLATION: Private Google Access disabled
  # NIST SC-7: Requires controlled access to cloud services
  private_ip_google_access = false

  # No VPC Flow Logs configured
  # NIST AU-2, AU-6: Requires comprehensive network monitoring

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# VIOLATION: No default-deny firewall rules
# NIST SC-7(5): Requires deny-by-default, allow-by-exception

# ============================================================================
# VIOLATION #1: Public GKE Cluster with No Private Nodes
# NIST SC-7 (Boundary Protection), AC-4 (Information Flow Enforcement)
# ============================================================================

resource "google_container_cluster" "non_compliant_cluster" {
  name     = "non-compliant-cluster"
  location = var.zone
  network  = google_compute_network.demo_vpc.name
  subnetwork = google_compute_subnetwork.demo_subnet.name

  # VIOLATION: Public control plane endpoint, no private nodes
  # NIST SC-7: Requires network boundaries and access control
  # No private_cluster_config block = public cluster

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # VIOLATION: Network policy disabled
  # NIST SC-7(5): Requires micro-segmentation
  network_policy {
    enabled = false
  }

  # VIOLATION: Binary Authorization disabled
  # NIST CM-7 (Least Functionality), SI-7 (Software Integrity)
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # VIOLATION: No Workload Identity
  # NIST IA-2, AC-6: Requires strong authentication and least privilege
  # workload_identity_config not configured

  # VIOLATION: No application-layer secrets encryption (CMEK for etcd)
  # NIST SC-28 (Protection of Information at Rest), SC-12 (Cryptographic Key Management)
  # database_encryption not configured

  # VIOLATION: No security posture or vulnerability scanning
  # NIST SI-2 (Flaw Remediation), RA-5 (Vulnerability Monitoring)
  # security_posture_config not configured

  depends_on = [google_project_service.services]
}

resource "google_container_node_pool" "non_compliant_nodes" {
  name       = "non-compliant-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.non_compliant_cluster.name
  node_count = 2

  # VIOLATION: No automatic repairs (auto_upgrade required by GKE with release channel)
  # NIST SI-2: Requires timely flaw remediation
  management {
    auto_repair  = false
    auto_upgrade = true  # Required by GKE API when using release channel
  }

  node_config {
    machine_type = "e2-standard-4"

    # VIOLATION: Using default Compute Engine service account
    # NIST AC-6: Requires least privilege
    # service_account not specified = uses default (overly permissive)

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # No workload metadata config for Workload Identity
    # NIST IA-2: Requires multi-factor authentication
  }
}

# ============================================================================
# VIOLATION #4: Cloud SQL - Public IP, No CMEK, No SSL Required
# NIST SC-8 (Transmission Confidentiality), SC-28, AC-17 (Remote Access)
# ============================================================================

resource "google_sql_database_instance" "demo_db" {
  name             = "non-compliant-sql"
  database_version = "POSTGRES_15"
  region           = var.region

  # VIOLATION: No CMEK encryption
  # NIST SC-12, SC-28: Requires customer-managed encryption keys
  # encryption_key_name not specified

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      # VIOLATION: Public IP enabled with 0.0.0.0/0 access
      # NIST AC-17: Requires controlled remote access
      ipv4_enabled = true

      authorized_networks {
        name  = "allow-all"
        value = "0.0.0.0/0"
      }

      # VIOLATION: SSL not required
      # NIST SC-8: Requires encryption in transit
      require_ssl = false
    }

    # VIOLATION: Minimal backup retention
    # NIST CP-9 (System Backup)
    backup_configuration {
      enabled = true
      backup_retention_settings {
        retained_backups = 7 # Only 7 days
      }
      # No point-in-time recovery
      point_in_time_recovery_enabled = false
    }

    # VIOLATION: No data deletion protection
    # NIST CP-6, MP-6: Requires protection against data loss
  }

  deletion_protection = false
  depends_on          = [google_project_service.services]
}

resource "google_sql_database" "demo_db" {
  name     = "demo-db"
  instance = google_sql_database_instance.demo_db.name
}

resource "google_sql_user" "demo_user" {
  name     = "demo-user"
  instance = google_sql_database_instance.demo_db.name
  password = var.db_password
}

# ============================================================================
# VIOLATION #4: Storage - No CMEK, Public Access, No UBLA
# NIST SC-28, AC-3 (Access Enforcement)
# ============================================================================

resource "google_storage_bucket" "model_storage" {
  name          = "${var.project_id}-llama-models-non-compliant"
  location      = var.region
  force_destroy = true

  # VIOLATION: No CMEK encryption
  # NIST SC-28: Requires customer-managed encryption
  # encryption block not specified

  # VIOLATION PREVENTED BY ASSURED WORKLOADS ✅
  # Uniform bucket-level access disabled (allows ACLs)
  # NIST AC-3: Requires consistent access controls
  # uniform_bucket_level_access = false  # ← BLOCKED by constraint: constraints/storage.uniformBucketLevelAccess
  # Assured Workloads enforces UBLA=true, cannot disable it

  # VIOLATION: No public access prevention
  # NIST AC-3: Requires access enforcement
  # public_access_prevention not set

  # VIOLATION: No versioning
  # NIST CP-9: Requires backup and recovery capabilities
  versioning {
    enabled = false
  }

  # VIOLATION: No retention policy
  # NIST AU-11: Requires audit record retention
}

# VIOLATION: Making model bucket publicly accessible
# NIST AC-3: Violates access enforcement requirements
resource "google_storage_bucket_iam_member" "public_models" {
  bucket = google_storage_bucket.model_storage.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ============================================================================
# VIOLATION #5: IAM - Overprivileged Service Account
# NIST AC-2 (Account Management), AC-6 (Least Privilege)
# ============================================================================

resource "google_service_account" "overprivileged_sa" {
  account_id   = "overprivileged-sa"
  display_name = "Overprivileged Service Account (NON-COMPLIANT)"
}

# VIOLATION PREVENTED BY ASSURED WORKLOADS ✅
# Granting Editor role (overly broad permissions)
# NIST AC-6: Requires least privilege
# resource "google_project_iam_member" "editor_role" {
#   project = var.project_id
#   role    = "roles/editor"
#   member  = "serviceAccount:${google_service_account.overprivileged_sa.email}"
# }
# ← BLOCKED: "Error 403: Policy update access denied"
# Assured Workloads prevents granting overly broad roles like Editor

# VIOLATION PREVENTED BY ASSURED WORKLOADS ✅
# Creating long-lived service account key
# NIST IA-5 (Authenticator Management): Requires key rotation
# resource "google_service_account_key" "non_compliant_key" {
#   service_account_id = google_service_account.overprivileged_sa.name
# }
# ← BLOCKED by constraint: constraints/iam.disableServiceAccountKeyCreation
# Assured Workloads prevents service account key creation

# ============================================================================
# VIOLATION #6: Logging - Minimal Audit Logs, Short Retention, No CMEK
# NIST AU-2 (Event Logging), AU-9 (Protection of Audit Information), AU-11 (Audit Record Retention)
# ============================================================================

# Only default Admin Activity logs enabled (free tier)
# No Data Access logs configured - NIST AU-2 violation

# VIOLATION: Minimal log retention (30 days by default)
# NIST AU-11: Requires 365+ day retention for FedRAMP High
# NOTE: Modifying log bucket config requires additional IAM permissions
# For this demo, we accept the default 30-day retention as a violation
# resource "google_logging_project_bucket_config" "default" {
#   project        = var.project_id
#   location       = "global"
#   retention_days = 30
#   bucket_id      = "_Default"
# }
# The default log bucket already exists with 30-day retention (violation demonstrated)

# ============================================================================
# VIOLATION #10: llama.cpp Deployment - Public LoadBalancer, No Auth, No mTLS
# NIST SC-8 (Transmission Confidentiality), AC-2 (Account Management)
# ============================================================================

# Note: This would normally be in a separate kubernetes manifest, but showing
# as null_resource with kubectl apply to demonstrate the deployment pattern

resource "null_resource" "deploy_llama_non_compliant" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${google_container_cluster.non_compliant_cluster.name} \
        --zone=${var.zone} \
        --project=${var.project_id}

      kubectl create namespace llama-demo --dry-run=client -o yaml | kubectl apply -f -

      # Upload a small model to the public bucket (for demo)
      echo "Downloading TinyLlama model..."
      curl -L -o tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
        "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf" || true

      if [ -f tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf ]; then
        gsutil cp tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf gs://${google_storage_bucket.model_storage.name}/models/
      fi

      # Deploy llama.cpp with all security violations
      kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: llama-config
  namespace: llama-demo
data:
  # VIOLATION: Sensitive config in ConfigMap (not encrypted)
  # NIST SC-28: Requires encryption at rest
  db_connection: "${google_sql_database_instance.demo_db.connection_name}"
  db_password: "${var.db_password}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-server
  namespace: llama-demo
  labels:
    app: llama-server
    compliance: non-compliant
spec:
  replicas: 1
  selector:
    matchLabels:
      app: llama-server
  template:
    metadata:
      labels:
        app: llama-server
    spec:
      # VIOLATION: No service account specified (uses default)
      # NIST AC-6: Requires least privilege

      # VIOLATION: No security context
      # NIST AC-6: Requires access controls

      initContainers:
      - name: download-model
        image: google/cloud-sdk:slim
        command:
          - gsutil
          - cp
          - gs://${google_storage_bucket.model_storage.name}/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
          - /models/model.gguf
        volumeMounts:
        - name: models
          mountPath: /models

      containers:
      - name: llama-server
        image: ghcr.io/ggml-org/llama.cpp:server
        args:
          - "-m"
          - "/models/model.gguf"
          - "--host"
          - "0.0.0.0"
          - "--port"
          - "8080"
          # VIOLATION: No --api-key flag (unauthenticated)
          # NIST AC-2, IA-2: Requires identification and authentication
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        volumeMounts:
        - name: models
          mountPath: /models
        env:
        - name: DB_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: llama-config
              key: db_password
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
      volumes:
      - name: models
        emptyDir:
          sizeLimit: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: llama-server
  namespace: llama-demo
  labels:
    app: llama-server
spec:
  # VIOLATION: Public LoadBalancer (exposed to internet)
  # NIST SC-7: Requires boundary protection
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: llama-server
EOF

      echo "Waiting for LoadBalancer IP..."
      kubectl wait --for=condition=ready pod -l app=llama-server -n llama-demo --timeout=300s || true
      kubectl get svc llama-server -n llama-demo
    EOT
  }

  depends_on = [
    google_container_node_pool.non_compliant_nodes,
    google_storage_bucket_iam_member.public_models
  ]
}

# ============================================================================
# SUMMARY OF VIOLATIONS (This Commit)
# ============================================================================
# KEY FINDING: Assured Workloads prevents 3/10 violations, allows 7/10
#
# VIOLATIONS THAT ASSURED WORKLOADS ALLOWS (7):
# 1. Public GKE cluster (no private nodes/endpoint) - SC-7 ❌
# 2. No Binary Authorization, Workload Identity, or GKE secrets CMEK - CM-7, IA-2, SC-28 ❌
# 3. No vulnerability scanning, no auto-repairs - SI-2, RA-5 ❌
# 4. Cloud SQL: public IP (0.0.0.0/0), no CMEK, no SSL - AC-17, SC-8, SC-28 ❌
# 5. Storage: no CMEK, publicly accessible (allUsers) - SC-28, AC-3 ❌
# 6. Network: no VPC-SC, no Private Google Access, no firewall rules - SC-7 ❌
# 7. Logging: minimal audit logs, 30-day retention, no CMEK - AU-2, AU-9, AU-11 ❌
# 8. No DR planning: single-region, minimal backups, no CMEK - CP-6, CP-9 ❌
# 9. llama.cpp: public LoadBalancer, no auth, HTTP only, no mTLS - SC-7, SC-8, AC-2 ❌
#
# VIOLATIONS THAT ASSURED WORKLOADS PREVENTS (3):
# 10. Storage: no UBLA (Uniform Bucket-Level Access) - AC-3 ✅ BLOCKED
# 11. IAM: overprivileged roles (Editor) - AC-6 ✅ BLOCKED
# 12. IAM: service account keys - IA-5 ✅ BLOCKED
#
# CONCLUSION: Assured Workloads provides platform-level controls but does NOT
# prevent most service-specific misconfigurations. 70% of violations are still possible!
#
# Next commits will remediate the 7 allowed violations incrementally.
# ============================================================================
