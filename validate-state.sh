#!/bin/bash
#
# Comprehensive GKE Compliance Validation Script
# Tests FedRAMP High / DoD IL5 requirements
#
# Usage:
#   ./validate-state.sh
#   ./validate-state.sh --report output.json
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

# Configuration
PROJECT_ID=${PROJECT_ID:-"real-slim-shady-fedramp-high"}
REGION=${REGION:-"us-central1"}
ZONE=${ZONE:-"us-central1-a"}
CLUSTER=${CLUSTER:-"non-compliant-cluster"}
GENERATE_REPORT=false
REPORT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --report)
      GENERATE_REPORT=true
      REPORT_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Results array for JSON report
declare -a RESULTS

# Helper functions
print_header() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
  echo -e "${YELLOW}[TEST $TOTAL] $1${NC}"
}

pass() {
  echo -e "${GREEN}✅ PASS:${NC} $1"
  ((PASSED++))
  if [[ $GENERATE_REPORT == true ]]; then
    RESULTS+=("{\"test\":\"$2\",\"status\":\"PASS\",\"message\":\"$1\"}")
  fi
}

fail() {
  echo -e "${RED}❌ FAIL:${NC} $1"
  ((FAILED++))
  if [[ $GENERATE_REPORT == true ]]; then
    RESULTS+=("{\"test\":\"$2\",\"status\":\"FAIL\",\"message\":\"$1\",\"risk\":\"$3\"}")
  fi
}

warn() {
  echo -e "${YELLOW}⚠️  WARN:${NC} $1"
  ((WARNINGS++))
  if [[ $GENERATE_REPORT == true ]]; then
    RESULTS+=("{\"test\":\"$2\",\"status\":\"WARN\",\"message\":\"$1\"}")
  fi
}

# Main validation function
run_validation() {
  print_header "GKE Assured Workloads Compliance Validation"

  echo "Project: $PROJECT_ID"
  echo "Cluster: $CLUSTER"
  echo "Zone: $ZONE"
  echo ""

  # Section A: Assured Workloads Platform Controls
  print_header "Section A: Platform-Level Controls (Assured Workloads)"

  ((TOTAL++))
  print_test "UBLA Enforcement on Storage Buckets"
  BUCKET="${PROJECT_ID}-llama-models-non-compliant"
  if gsutil ubla get gs://$BUCKET 2>&1 | grep -q "Enabled"; then
    pass "UBLA is enforced on storage bucket" "ubla-enforcement"
  else
    fail "UBLA not enforced on storage bucket" "ubla-enforcement" "CRITICAL"
  fi

  ((TOTAL++))
  print_test "Public Bucket IAM Blocked (allUsers)"
  if gsutil iam get gs://$BUCKET 2>&1 | grep -q "allUsers"; then
    fail "Public access (allUsers) detected in IAM policy" "public-bucket-iam" "CRITICAL"
  else
    pass "No public IAM bindings (allUsers) detected" "public-bucket-iam"
  fi

  # Section B: GKE Cluster Security
  print_header "Section B: GKE Cluster Security (SC-7, AC-4)"

  ((TOTAL++))
  print_test "Private GKE Cluster Endpoint"
  PRIVATE_ENDPOINT=$(gcloud container clusters describe $CLUSTER --zone=$ZONE \
    --format="value(privateClusterConfig.enablePrivateEndpoint)" 2>/dev/null || echo "")
  if [[ "$PRIVATE_ENDPOINT" == "True" ]]; then
    pass "Private cluster endpoint enabled" "private-endpoint"
  else
    fail "Public cluster endpoint exposed (SC-7 violation)" "private-endpoint" "CRITICAL"
  fi

  ((TOTAL++))
  print_test "Private Nodes (No External IPs)"
  EXTERNAL_IPS=$(gcloud compute instances list \
    --filter="name:gke-$CLUSTER" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null | wc -l)
  if [[ $EXTERNAL_IPS -eq 0 ]]; then
    pass "Nodes have no external IPs (private nodes)" "private-nodes"
  else
    fail "Nodes have external IPs: $EXTERNAL_IPS nodes (SC-7 violation)" "private-nodes" "CRITICAL"
  fi

  ((TOTAL++))
  print_test "Network Policy Enabled"
  NETWORK_POLICY=$(gcloud container clusters describe $CLUSTER --zone=$ZONE \
    --format="value(networkPolicy.enabled)" 2>/dev/null || echo "False")
  if [[ "$NETWORK_POLICY" == "True" ]]; then
    pass "Network policies enabled for micro-segmentation" "network-policy"
  else
    fail "Network policies disabled (SC-7(5) violation)" "network-policy" "HIGH"
  fi

  # Section C: FIPS 140-2 Encryption
  print_header "Section C: FIPS 140-2 Encryption (SC-28, SC-12)"

  ((TOTAL++))
  print_test "GKE Secrets Encryption (CMEK for etcd)"
  DB_ENCRYPTION=$(gcloud container clusters describe $CLUSTER --zone=$ZONE \
    --format="value(databaseEncryption.state)" 2>/dev/null || echo "DECRYPTED")
  if [[ "$DB_ENCRYPTION" == "ENCRYPTED" ]]; then
    pass "CMEK enabled for Kubernetes secrets (etcd encryption)" "gke-cmek"
  else
    fail "No CMEK for Kubernetes secrets (SC-28 violation)" "gke-cmek" "HIGH"
  fi

  ((TOTAL++))
  print_test "Cloud SQL CMEK Encryption"
  SQL_CMEK=$(gcloud sql instances describe non-compliant-sql \
    --format="value(diskEncryptionConfiguration.kmsKeyName)" 2>/dev/null || echo "")
  if [[ -n "$SQL_CMEK" ]]; then
    pass "Cloud SQL uses CMEK encryption" "sql-cmek"
  else
    fail "Cloud SQL uses Google-managed keys only (SC-28 violation)" "sql-cmek" "HIGH"
  fi

  ((TOTAL++))
  print_test "Storage CMEK Encryption"
  STORAGE_CMEK=$(gsutil encryption get gs://$BUCKET 2>&1 | grep "Encryption key:" || echo "")
  if [[ -n "$STORAGE_CMEK" ]]; then
    pass "Storage bucket uses CMEK encryption" "storage-cmek"
  else
    fail "Storage uses Google-managed keys only (SC-28 violation)" "storage-cmek" "HIGH"
  fi

  # Section D: Binary Authorization
  print_header "Section D: Binary Authorization (CM-7, SI-7)"

  ((TOTAL++))
  print_test "Binary Authorization Policy"
  BINAUTHZ=$(gcloud container clusters describe $CLUSTER --zone=$ZONE \
    --format="value(binaryAuthorization.evaluationMode)" 2>/dev/null || echo "DISABLED")
  if [[ "$BINAUTHZ" == *"ENFORCE"* ]]; then
    pass "Binary Authorization enforced" "binary-authz"
  else
    fail "Binary Authorization disabled (CM-7, SI-7 violation)" "binary-authz" "MEDIUM"
  fi

  # Section E: Workload Identity
  print_header "Section E: Workload Identity (IA-2, AC-6)"

  ((TOTAL++))
  print_test "Workload Identity Configuration"
  WORKLOAD_POOL=$(gcloud container clusters describe $CLUSTER --zone=$ZONE \
    --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null || echo "")
  if [[ -n "$WORKLOAD_POOL" ]]; then
    pass "Workload Identity enabled: $WORKLOAD_POOL" "workload-identity"
  else
    fail "Workload Identity not configured (IA-2 violation)" "workload-identity" "HIGH"
  fi

  ((TOTAL++))
  print_test "Node Pool Workload Metadata"
  WI_METADATA=$(gcloud container node-pools describe non-compliant-node-pool \
    --cluster=$CLUSTER --zone=$ZONE \
    --format="value(config.workloadMetadataConfig.mode)" 2>/dev/null || echo "")
  if [[ "$WI_METADATA" == "GKE_METADATA" ]]; then
    pass "Node pool configured for Workload Identity" "wi-metadata"
  else
    fail "Node pool not configured for Workload Identity" "wi-metadata" "HIGH"
  fi

  # Section F: mTLS & Service Mesh
  print_header "Section F: mTLS & Service Mesh (SC-8, SC-23)"

  ((TOTAL++))
  print_test "Service Mesh Installation"
  if kubectl get namespace istio-system &>/dev/null; then
    pass "Istio service mesh installed" "service-mesh"
  else
    fail "No service mesh deployed (SC-8 violation)" "service-mesh" "CRITICAL"
  fi

  ((TOTAL++))
  print_test "mTLS Policy Enforcement"
  MTLS_POLICY=$(kubectl get peerauthentication -A -o yaml 2>/dev/null | grep "mode: STRICT" || echo "")
  if [[ -n "$MTLS_POLICY" ]]; then
    pass "STRICT mTLS policy enforced" "mtls-policy"
  else
    fail "No STRICT mTLS policy (SC-8 violation)" "mtls-policy" "CRITICAL"
  fi

  # Section G: Vulnerability Management
  print_header "Section G: Vulnerability Management (SI-2, RA-5)"

  ((TOTAL++))
  print_test "Container Vulnerability Scanning"
  VULN_MODE=$(gcloud container clusters describe $CLUSTER --zone=$ZONE \
    --format="value(securityPostureConfig.vulnerabilityMode)" 2>/dev/null || echo "DISABLED")
  if [[ "$VULN_MODE" != "DISABLED" ]] && [[ -n "$VULN_MODE" ]]; then
    pass "Vulnerability scanning enabled: $VULN_MODE" "vuln-scanning"
  else
    fail "Vulnerability scanning disabled (SI-2 violation)" "vuln-scanning" "HIGH"
  fi

  ((TOTAL++))
  print_test "Node Auto-Repair"
  AUTO_REPAIR=$(gcloud container node-pools describe non-compliant-node-pool \
    --cluster=$CLUSTER --zone=$ZONE \
    --format="value(management.autoRepair)" 2>/dev/null || echo "False")
  if [[ "$AUTO_REPAIR" == "True" ]]; then
    pass "Node auto-repair enabled" "auto-repair"
  else
    fail "Node auto-repair disabled (SI-2 violation)" "auto-repair" "MEDIUM"
  fi

  ((TOTAL++))
  print_test "Node Auto-Upgrade"
  AUTO_UPGRADE=$(gcloud container node-pools describe non-compliant-node-pool \
    --cluster=$CLUSTER --zone=$ZONE \
    --format="value(management.autoUpgrade)" 2>/dev/null || echo "False")
  if [[ "$AUTO_UPGRADE" == "True" ]]; then
    pass "Node auto-upgrade enabled" "auto-upgrade"
  else
    warn "Node auto-upgrade disabled (consider enabling)" "auto-upgrade"
  fi

  # Section H: Network Security
  print_header "Section H: Network Security (SC-7(5), SC-7(8))"

  ((TOTAL++))
  print_test "Private Google Access"
  PGA=$(gcloud compute networks subnets describe demo-subnet \
    --region=$REGION \
    --format="value(privateIpGoogleAccess)" 2>/dev/null || echo "False")
  if [[ "$PGA" == "True" ]]; then
    pass "Private Google Access enabled" "private-google-access"
  else
    fail "Private Google Access disabled (SC-7 violation)" "private-google-access" "HIGH"
  fi

  ((TOTAL++))
  print_test "VPC Flow Logs"
  FLOW_LOGS=$(gcloud compute networks subnets describe demo-subnet \
    --region=$REGION \
    --format="value(enableFlowLogs)" 2>/dev/null || echo "False")
  if [[ "$FLOW_LOGS" == "True" ]]; then
    pass "VPC Flow Logs enabled" "flow-logs"
  else
    fail "VPC Flow Logs disabled (AU-2 violation)" "flow-logs" "MEDIUM"
  fi

  # Section I: Audit & Monitoring
  print_header "Section I: Audit & Monitoring (AU-2, AU-6, AU-9, AU-11)"

  ((TOTAL++))
  print_test "Log Retention Period"
  LOG_RETENTION=$(gcloud logging buckets describe _Default --location=global \
    --format="value(retentionDays)" 2>/dev/null || echo "30")
  if [[ $LOG_RETENTION -ge 365 ]]; then
    pass "Log retention meets requirements: $LOG_RETENTION days" "log-retention"
  else
    fail "Log retention insufficient: $LOG_RETENTION days (AU-11 violation - need 365+)" "log-retention" "HIGH"
  fi

  ((TOTAL++))
  print_test "Log Encryption (CMEK)"
  LOG_CMEK=$(gcloud logging buckets describe _Default --location=global \
    --format="value(cmekSettings.kmsKeyName)" 2>/dev/null || echo "")
  if [[ -n "$LOG_CMEK" ]]; then
    pass "Logs encrypted with CMEK" "log-cmek"
  else
    fail "Logs use Google-managed keys (AU-9 violation)" "log-cmek" "MEDIUM"
  fi

  # Section J: Cloud SQL Security
  print_header "Section J: Cloud SQL Security (AC-17, SC-8)"

  ((TOTAL++))
  print_test "Cloud SQL Public IP Configuration"
  SQL_PUBLIC_IP=$(gcloud sql instances describe non-compliant-sql \
    --format="value(ipAddresses[0].type)" 2>/dev/null || echo "")
  if [[ "$SQL_PUBLIC_IP" == "PRIMARY" ]]; then
    SQL_IP=$(gcloud sql instances describe non-compliant-sql \
      --format="value(ipAddresses[0].ipAddress)" 2>/dev/null || echo "")
    fail "Cloud SQL has public IP: $SQL_IP (AC-17 violation)" "sql-public-ip" "CRITICAL"
  else
    pass "Cloud SQL uses private IP only" "sql-public-ip"
  fi

  ((TOTAL++))
  print_test "Cloud SQL SSL Requirement"
  SQL_SSL=$(gcloud sql instances describe non-compliant-sql \
    --format="value(settings.ipConfiguration.requireSsl)" 2>/dev/null || echo "False")
  if [[ "$SQL_SSL" == "True" ]]; then
    pass "Cloud SQL requires SSL/TLS" "sql-ssl"
  else
    fail "Cloud SQL does not require SSL (SC-8 violation)" "sql-ssl" "CRITICAL"
  fi
}

# Generate compliance score
calculate_score() {
  print_header "Compliance Score Summary"

  COMPLIANCE_PCT=$(echo "scale=1; $PASSED * 100 / $TOTAL" | bc)

  echo "Total Tests Run: $TOTAL"
  echo -e "${GREEN}Passed: $PASSED${NC}"
  echo -e "${RED}Failed: $FAILED${NC}"
  echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
  echo ""
  echo -e "Compliance Score: ${BLUE}$COMPLIANCE_PCT%${NC}"
  echo ""

  if (( $(echo "$COMPLIANCE_PCT < 50" | bc -l) )); then
    echo -e "${RED}Status: NON-COMPLIANT (Critical)${NC}"
  elif (( $(echo "$COMPLIANCE_PCT < 80" | bc -l) )); then
    echo -e "${YELLOW}Status: PARTIALLY COMPLIANT (Needs Work)${NC}"
  elif (( $(echo "$COMPLIANCE_PCT < 100" | bc -l) )); then
    echo -e "${YELLOW}Status: MOSTLY COMPLIANT (Minor Issues)${NC}"
  else
    echo -e "${GREEN}Status: FULLY COMPLIANT${NC}"
  fi
}

# Generate JSON report
generate_json_report() {
  if [[ $GENERATE_REPORT == true ]]; then
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    COMPLIANCE_PCT=$(echo "scale=2; $PASSED * 100 / $TOTAL" | bc)

    cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "project": "$PROJECT_ID",
  "cluster": "$CLUSTER",
  "summary": {
    "total_tests": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS,
    "compliance_percentage": $COMPLIANCE_PCT
  },
  "tests": [
    $(IFS=,; echo "${RESULTS[*]}")
  ]
}
EOF

    echo ""
    echo -e "${GREEN}Compliance report saved to: $REPORT_FILE${NC}"
  fi
}

# Main execution
main() {
  run_validation
  calculate_score
  generate_json_report
}

main
