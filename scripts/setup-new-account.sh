#!/bin/bash
# NT548 - bootstrap a separate deployment in the currently authenticated AWS account.
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
PROJECT_NAME="${PROJECT_NAME:-NT548}"
DOMAIN_NAME="${DOMAIN_NAME:-example.invalid}"
APP_IMAGE_TAG="${APP_IMAGE_TAG:-bootstrap}"

required_env=(GITHUB_CONNECTION_ARN GITHUB_REPOSITORY APPROVAL_EMAIL)
for name in "${required_env[@]}"; do
    if [ -z "${!name:-}" ]; then
        echo "ERROR: $name is required. See README.md -> Deploy to another AWS account."
        exit 1
    fi
done

for command_name in aws terraform python3 openssl; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "ERROR: Required command not found: $command_name"
        exit 1
    }
done

echo "=================================================================="
echo "NT548 - NEW AWS ACCOUNT BOOTSTRAP"
echo "=================================================================="

echo "[1/6] Verifying AWS identity"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="nt548-terraform-state-${ACCOUNT_ID}"
echo "Account: $ACCOUNT_ID | Region: $AWS_REGION"

case "$GITHUB_CONNECTION_ARN" in
    arn:aws:codeconnections:"$AWS_REGION":"$ACCOUNT_ID":connection/*|arn:aws:codestar-connections:"$AWS_REGION":"$ACCOUNT_ID":connection/*) ;;
    *)
        echo "ERROR: GITHUB_CONNECTION_ARN must belong to account $ACCOUNT_ID and region $AWS_REGION."
        exit 1
        ;;
esac

echo "[2/6] Verifying regional GitHub connection"
CONNECTION_STATUS=$(aws codeconnections get-connection \
    --connection-arn "$GITHUB_CONNECTION_ARN" \
    --region "$AWS_REGION" \
    --query 'Connection.ConnectionStatus' \
    --output text)
if [ "$CONNECTION_STATUS" != "AVAILABLE" ]; then
    echo "ERROR: GitHub connection must be AVAILABLE, current status: $CONNECTION_STATUS"
    exit 1
fi

echo "[3/6] Creating account-local Terraform state bucket"
terraform -chdir=terraform/bootstrap init -input=false
terraform -chdir=terraform/bootstrap apply -auto-approve -var="aws_region=$AWS_REGION"

echo "[4/6] Creating application secret when absent"
if ! aws secretsmanager describe-secret --secret-id "nt548/app-secrets" --region "$AWS_REGION" >/dev/null 2>&1; then
    JWT_SECRET="${NT548_JWT_SECRET:-$(openssl rand -hex 32)}"
    ADMIN_PASSWORD="${NT548_ADMIN_PASSWORD:-$(openssl rand -hex 16)}"
    SECRET_JSON=$(python3 -c 'import json,sys; print(json.dumps({"JWT_SECRET":sys.argv[1],"ADMIN_PASSWORD":sys.argv[2]}))' "$JWT_SECRET" "$ADMIN_PASSWORD")
    aws secretsmanager create-secret \
        --name "nt548/app-secrets" \
        --description "Application credentials for NT548 microservices" \
        --secret-string "$SECRET_JSON" \
        --region "$AWS_REGION" >/dev/null
    echo "Created nt548/app-secrets. Retrieve ADMIN_PASSWORD from Secrets Manager when needed."
else
    echo "Secret nt548/app-secrets already exists; leaving its value unchanged."
fi

echo "[5/6] Generating account-local Terraform variable files"
cat > terraform/environments/shared/terraform.tfvars <<EOF
aws_region            = "$AWS_REGION"
project_name          = "$PROJECT_NAME"
domain_name           = "$DOMAIN_NAME"
github_connection_arn = "$GITHUB_CONNECTION_ARN"
github_repository     = "$GITHUB_REPOSITORY"
EOF

cat > terraform/environments/dev/terraform.tfvars <<EOF
aws_region            = "$AWS_REGION"
github_connection_arn = "$GITHUB_CONNECTION_ARN"
github_repository     = "$GITHUB_REPOSITORY"
EOF

cat > terraform/environments/prod/terraform.tfvars <<EOF
aws_region             = "$AWS_REGION"
approval_email         = "$APPROVAL_EMAIL"
github_connection_arn  = "$GITHUB_CONNECTION_ARN"
github_repository      = "$GITHUB_REPOSITORY"
app_image_tag          = "$APP_IMAGE_TAG"
service_desired_count  = 0
EOF

echo "[6/6] Bootstrap complete"
echo "State bucket: $STATE_BUCKET"
echo ""
echo "Deploy in this order:"
echo "  terraform -chdir=terraform/environments/shared init -reconfigure -backend-config=\"bucket=$STATE_BUCKET\" -backend-config=\"region=$AWS_REGION\""
echo "  terraform -chdir=terraform/environments/shared apply"
echo "  terraform -chdir=terraform/environments/dev init -reconfigure -backend-config=\"bucket=$STATE_BUCKET\" -backend-config=\"region=$AWS_REGION\""
echo "  terraform -chdir=terraform/environments/dev apply"
echo "  terraform -chdir=terraform/environments/prod init -reconfigure -backend-config=\"bucket=$STATE_BUCKET\" -backend-config=\"region=$AWS_REGION\""
echo "  terraform -chdir=terraform/environments/prod apply"
echo ""
echo "PROD starts with service_desired_count=0 so missing bootstrap images cannot block ECS."
echo "After the first successful PROD image build, set service_desired_count=1 and apply PROD again."
