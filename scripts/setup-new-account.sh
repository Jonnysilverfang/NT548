#!/bin/bash
# ==============================================================================
# NT548 - New AWS Account Setup & Bootstrap Script
# ==============================================================================
set -eo pipefail

AWS_REGION="${AWS_REGION:-ap-southeast-1}"

echo "=================================================================="
echo "🚀 NT548: INITIALIZING NEW AWS ACCOUNT DEPLOYMENT"
echo "=================================================================="

# 1. Verify AWS Identity
echo "[1/5] 🔍 Checking AWS credentials..."
if ! ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    echo "❌ ERROR: AWS credentials not found or invalid. Run 'aws configure' first."
    exit 1
fi
echo "✅ Logged into AWS Account: $ACCOUNT_ID (Region: $AWS_REGION)"

# 2. Check Terraform
echo "[2/5] 🔍 Checking Terraform binary..."
if ! command -v terraform &>/dev/null; then
    echo "❌ ERROR: Terraform is not installed. Please install Terraform >= 1.5.0."
    exit 1
fi
TF_VERSION=$(terraform version | head -n 1)
echo "✅ Found $TF_VERSION"

# 3. Bootstrap Remote State S3 Bucket
echo "[3/5] 📦 Bootstrapping Terraform Remote State S3 Bucket..."
STATE_BUCKET="nt548-terraform-state-$ACCOUNT_ID"

cd terraform/bootstrap
terraform init -input=false >/dev/null
terraform apply -auto-approve -var="aws_region=$AWS_REGION"
cd ../..
echo "✅ Terraform state bucket ready: $STATE_BUCKET"

# 4. Check or Create Secrets Manager Secret for Application
echo "[4/5] 🔐 Checking AWS Secrets Manager for 'nt548/app-secrets'..."
SECRET_EXISTS=$(aws secretsmanager describe-secret --secret-id "nt548/app-secrets" --region "$AWS_REGION" --query "ARN" --output text 2>/dev/null || true)

if [ -z "$SECRET_EXISTS" ] || [ "$SECRET_EXISTS" = "None" ]; then
    echo "Creating secret 'nt548/app-secrets'..."
    aws secretsmanager create-secret \
        --name "nt548/app-secrets" \
        --description "Application credentials for NT548 microservices" \
        --secret-string '{"JWT_SECRET":"super-secret-jwt-key-change-in-production","ADMIN_PASSWORD":"nt548-demo-password"}' \
        --region "$AWS_REGION" >/dev/null
    echo "✅ Secret 'nt548/app-secrets' created successfully."
else
    echo "✅ Secret 'nt548/app-secrets' already exists: $SECRET_EXISTS"
fi

# 5. Check GitHub Connection
echo "[5/5] 🔗 Checking GitHub CodeStar / CodeConnections..."
echo "ℹ️ Note: If you haven't created a GitHub connection in AWS CodePipeline yet:"
echo "   1. Open AWS Console -> CodePipeline -> Settings -> Connections"
echo "   2. Click 'Create connection', choose 'GitHub', name it 'nt548-github'"
echo "   3. Click 'Install a new app' and authorize your GitHub repository"
echo "   4. Copy the Connection ARN into terraform.tfvars files"
echo ""
echo "=================================================================="
echo "🎉 PREREQUISITES COMPLETED SUCCESSFULLY!"
echo "=================================================================="
echo "Next Steps to complete deployment on your AWS account:"
echo ""
echo "1. Copy terraform.tfvars.example -> terraform.tfvars in:"
echo "   - terraform/environments/shared/terraform.tfvars"
echo "   - terraform/environments/dev/terraform.tfvars"
echo "   - terraform/environments/prod/terraform.tfvars"
echo ""
echo "2. Deploy Shared Infrastructure (VPC, ALB, 8 ECR Repos, IAM Roles):"
echo "   cd terraform/environments/shared"
echo "   terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "   terraform apply"
echo ""
echo "3. Deploy DEV Pipeline (Optional/Parallel):"
echo "   cd ../dev"
echo "   terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "   terraform apply"
echo ""
echo "4. Deploy PROD Pipeline (Infra CI/CD + ECS Services):"
echo "   cd ../prod"
echo "   terraform init -backend-config=\"bucket=$STATE_BUCKET\""
echo "   terraform apply"
echo "=================================================================="
