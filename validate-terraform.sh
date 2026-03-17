#!/bin/bash
# ============================================================================
# Terraform Validation Script
# ============================================================================
# Run this locally before committing to catch errors early
#
# Usage:
#   chmod +x validate-terraform.sh
#   ./validate-terraform.sh
# ============================================================================

set -e

echo "=================================================="
echo "  Terraform Validation Script"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

# ============================================================================
# Check 1: Terraform installed
# ============================================================================
echo "Checking if Terraform is installed..."
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed${NC}"
    echo "   Please install Terraform: https://developer.hashicorp.com/terraform/downloads"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo -e "${GREEN}✅ Terraform $TERRAFORM_VERSION installed${NC}"
echo ""

# ============================================================================
# Check 2: Formatting
# ============================================================================
echo "=================================================="
echo "Check 1: Terraform Formatting"
echo "=================================================="

if terraform fmt -check -diff; then
    echo -e "${GREEN}✅ All files are properly formatted${NC}"
else
    echo -e "${YELLOW}⚠️  Some files need formatting${NC}"
    echo "   Run: terraform fmt -recursive"
    FAILED=1
fi
echo ""

# ============================================================================
# Check 3: Initialization
# ============================================================================
echo "=================================================="
echo "Check 2: Terraform Initialization"
echo "=================================================="

if terraform init -backend=false > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Terraform initialized successfully${NC}"
else
    echo -e "${RED}❌ Terraform initialization failed${NC}"
    terraform init -backend=false
    FAILED=1
fi
echo ""

# ============================================================================
# Check 4: Validation
# ============================================================================
echo "=================================================="
echo "Check 3: Terraform Validation"
echo "=================================================="

if terraform validate; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration validation failed${NC}"
    FAILED=1
fi
echo ""

# ============================================================================
# Check 5: Security Scanning (optional - requires tfsec)
# ============================================================================
echo "=================================================="
echo "Check 4: Security Scanning (Optional)"
echo "=================================================="

if command -v tfsec &> /dev/null; then
    echo "Running tfsec security scan..."
    if tfsec . --minimum-severity CRITICAL; then
        echo -e "${GREEN}✅ No critical security issues found${NC}"
    else
        echo -e "${YELLOW}⚠️  Security issues detected (see above)${NC}"
        echo "   Note: This demo intentionally has violations"
    fi
else
    echo -e "${YELLOW}⚠️  tfsec not installed (optional)${NC}"
    echo "   Install: brew install tfsec (macOS) or see https://github.com/aquasecurity/tfsec"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=================================================="
echo "  Validation Summary"
echo "=================================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "You can safely commit and push your changes."
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some checks failed${NC}"
    echo ""
    echo "Please fix the issues above before committing."
    echo ""
    exit 1
fi
