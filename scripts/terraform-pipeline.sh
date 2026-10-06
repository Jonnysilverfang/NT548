#!/bin/bash
# ==============================================================================
# terraform-pipeline.sh — Reusable runner for Terraform CI/CD operations
#
# Usage:
#   ./scripts/terraform-pipeline.sh fmt
#   ./scripts/terraform-pipeline.sh checkov
#   ./scripts/terraform-pipeline.sh validate <env>
#   ./scripts/terraform-pipeline.sh plan <env>
#   ./scripts/terraform-pipeline.sh apply <env>
#
# Environment options: prod, dev, shared
# ==============================================================================
set -euo pipefail

ACTION="${1:-}"
ENV_NAME="${2:-prod}"
AWS_REGION="${AWS_REGION:-ap-southeast-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ensure_terraform_initialized() {
    local target_dir="$ROOT_DIR/terraform/environments/$ENV_NAME"
    if [ ! -d "$target_dir" ]; then
        echo "❌ Environment directory not found: $target_dir"
        exit 1
    fi

    echo "⚙️ [TERRAFORM] Initializing $ENV_NAME backend in $target_dir..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    BUCKET_NAME="nt548-terraform-state-${ACCOUNT_ID}"

    cd "$target_dir"
    terraform init \
        -backend-config="bucket=${BUCKET_NAME}" \
        -backend-config="region=${AWS_REGION}" \
        -input=false
}

case "$ACTION" in
    fmt)
        echo "=================================================="
        echo "📐 [TERRAFORM] Checking code format"
        echo "=================================================="
        cd "$ROOT_DIR"
        terraform fmt -check -recursive
        echo "✅ [TERRAFORM] Format check passed."
        ;;

    checkov)
        echo "=================================================="
        echo "🛡️ [TERRAFORM] Running Checkov IaC Security Scan"
        echo "=================================================="
        cd "$ROOT_DIR"
        if [ -f .checkov.yml ]; then
            checkov --config-file .checkov.yml
        else
            checkov -d terraform/
        fi
        echo "✅ [TERRAFORM] Checkov security scan passed."
        ;;

    validate)
        echo "=================================================="
        echo "🔍 [TERRAFORM] Validating configuration for $ENV_NAME"
        echo "=================================================="
        ensure_terraform_initialized
        terraform validate
        echo "✅ [TERRAFORM] Validation successful for $ENV_NAME."
        ;;

    plan)
        echo "=================================================="
        echo "📋 [TERRAFORM] Generating execution plan for $ENV_NAME"
        echo "=================================================="
        ensure_terraform_initialized
        terraform plan -out=tfplan -input=false
        terraform show -no-color tfplan > tfplan.txt
        echo "✅ [TERRAFORM] Plan generated successfully for $ENV_NAME."
        echo "--- Plan summary (first 40 lines) ---"
        head -n 40 tfplan.txt || true
        ;;

    apply)
        echo "=================================================="
        echo "🚀 [TERRAFORM] Applying approved plan for $ENV_NAME"
        echo "=================================================="
        ensure_terraform_initialized
        if [ ! -f tfplan ]; then
            echo "❌ Plan artifact 'tfplan' not found in $(pwd)"
            exit 1
        fi
        terraform apply -auto-approve tfplan
        echo "✅ [TERRAFORM] Infrastructure successfully updated for $ENV_NAME."
        ;;

    *)
        echo "Usage: $0 <fmt|checkov|validate|plan|apply> [prod|dev|shared]"
        exit 1
        ;;
esac
