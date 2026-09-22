# NT548 - Enterprise Microservices Platform with Multi-Environment CI/CD

> **Course:** NT548 - DevOps Technologies and Applications  
> **AWS Region:** `ap-southeast-1` (Singapore)  
> **Architecture Pattern:** Dual ECR, Dual CodePipeline (`main` & `dev`), DEV Ephemeral with Cookie-based Routing, PROD Infrastructure CI/CD with Checkov Security Gate & Manual Approvals, ECS Native Rolling Deployment.

---

## 📑 Table of Contents
1. [Project Overview](#1-project-overview)
2. [Application Architecture & Ingress](#2-application-architecture--ingress)
3. [PROD CI/CD Pipeline (Infra + App)](#3-prod-cicd-pipeline-infra--app)
4. [DEV CI/CD Pipeline (Ephemeral)](#4-dev-cicd-pipeline-ephemeral)
5. [Frontend Stability & Root Cause Fix](#5-frontend-stability--root-cause-fix)
6. [Terraform Structure & State Management](#6-terraform-structure--state-management)
7. [ECR Repository Architecture](#7-ecr-repository-architecture)
8. [Checkov & Image Security Gates](#8-checkov--image-security-gates)
9. [ECS Rolling Deployment Strategy](#9-ecs-rolling-deployment-strategy)
10. [Hướng Dẫn Tái Sử Dụng & Triển Khai Trên AWS Account Mới (Multi-Account Setup Guide)](#10-hướng-dẫn-tái-sử-dụng--triển-khai-trên-aws-account-mới-multi-account-setup-guide)
11. [Hướng Dẫn Cấu Hình Tên Miền Thủ Công (Manual Custom Domain Setup)](#11-hướng-dẫn-cấu-hình-tên-miền-thủ-công-manual-custom-domain-setup)
12. [Verification & Smoke Testing (Kiểm Thử Nghiệm Thu)](#12-verification--smoke-testing-kiểm-thử-nghiệm-thu)

---

## 1. Project Overview

The **NT548** project implements an enterprise cloud-native microservices architecture on AWS Singapore (`ap-southeast-1`), completely decoupling DEV and PROD environments:

- **DEV Environment**: Ephemeral testing stack. Triggered on `git push dev`, verified via cookie-based routing (`Cookie: nt548-test=true`) on the shared Application Load Balancer, and immediately destroyed upon smoke test completion.
- **PROD Environment**: 24/7 high-availability fleet on AWS ECS Fargate, triggered on `git push main`. It features a two-tier gate: **Infrastructure CI/CD** (Terraform fmt, validate, Checkov security scan, Terraform plan, manual approval, and apply) followed by **Application CI/CD** (unit tests, Docker build, ECR image vulnerability scan, manual approval, and zero-downtime ECS rolling update).

---

## 2. Application Architecture & Ingress

The platform consists of 4 microservices running as AWS Fargate containers:
1. **Frontend (`frontend`)**: Nginx web server serving static SPA UI, providing `/health` endpoint (`text/plain`), and routing runtime requests.
2. **User Service (`be-user-service`)**: Node.js/Express service handling authentication, scrypt hashing, and JWT token issuance on port `5001`.
3. **Product Service (`be-product-service`)**: Python/Flask REST API serving product catalog on port `5002` (requires Bearer JWT).
4. **Order Service (`be-order-service`)**: Node.js/Express order management service on port `5003` (requires Bearer JWT).

### Ingress & Routing Topology:

```text
                                Internet
                                   │
                                   ▼
                         Shared ALB (Port 80 HTTP)
                              (<ALB_DNS_NAME>)
                                   │
         ┌─────────────────────────┴─────────────────────────┐
         │                                                   │
  Cookie: nt548-test=true                            Default PROD Rules
         │                                                   │
         ▼                                                   ├── /api/users*    ──► nt548-prod-tg-user (:5001)
  DEV Target Groups                                          ├── /api/products* ──► nt548-prod-tg-product (:5002)
 (Ephemeral: 80, 5001-5003)                                  ├── /api/orders*   ──► nt548-prod-tg-order (:5003)
         │                                                   └── /* (Default)   ──► nt548-prod-tg-fe (:80)
         ▼                                                   │
    ECS DEV Tasks                                            ▼
 (Created for testing)                                 ECS PROD Fleet
         │                                          (Always running 24/7)
         ▼
  Automated Smoke Test
         │
         ▼ (Pass or Fail)
  Guaranteed Cleanup
```

> **Important Ingress Note:** The automated deployment intentionally stops at the Application Load Balancer (ALB). No Route 53 records or ACM certificates are created automatically. The ALB DNS name is directly accessible for verification.

---

## 3. PROD CI/CD Pipeline (Infra + App)

The **PROD Pipeline** (`nt548-prod-pipeline`) is a V2 `QUEUED` CodePipeline with 7 sequential stages:

```text
GitHub main
    ↓
Source (CodeStarSourceConnection: main)
    ↓
InfraPlan (CodeBuild: nt548-prod-terraform-plan)
    ├── terraform fmt -check -recursive
    ├── checkov -d terraform --framework terraform
    ├── terraform init & validate
    ├── terraform plan -out=tfplan
    └── terraform show -no-color tfplan > tfplan.txt
    ↓
InfraApproval (Manual Approval via SNS: nt548-prod-infra-approval)
    ├── Human reviews tfplan and Checkov results
    └── Approved / Rejected
    ↓
InfraApply (CodeBuild: nt548-prod-terraform-apply)
    └── terraform apply -auto-approve tfplan (Applies exact approved plan)
    ↓
AppBuild (CodeBuild: nt548-prod-app-build)
    ├── Unit Tests & Syntax Checks (Node test runner, Python unittest, node -c, py_compile)
    ├── Docker Build with commit SHA tag
    ├── Push to PROD ECR (nt548-prod-*)
    ├── ECR Vulnerability Scan Gate (Fails if CRITICAL > 0 or HIGH > 0)
    └── Generate one imagedefinitions-<service>.json per ECS deploy action
    ↓
ProductionApproval (Manual Approval via SNS: nt548-prod-deployment-approval)
    ├── Human verifies commit SHA, image tag, ecr-scan-summary.json, and vulnerability count (0)
    └── Approved / Rejected
    ↓
AppDeploy (Native CodePipeline ECS Deploy Action)
    ├── ECS Rolling Update (desiredCount = runningCount = 1)
    ├── New task starts and registers to existing Target Group
    ├── ALB Health Check verifies /health (HTTP 200)
    ├── Traffic shifts to new task revision
    └── Old task revision drains and stops
```

---

## 4. DEV CI/CD Pipeline (Ephemeral)

Triggered on `git push dev`:

```text
git push dev
    ↓
AWS CodePipeline DEV (Source: GitHub dev)
    ↓
CodeBuild: Unit Test & Docker Build
    ↓
Push to DEV ECR Repositories (tag = commit SHA)
    ↓
ECR Vulnerability Scan
    ↓
EventBridge Rule matches scan completion
    ↓
Lambda Security Gate (Auto-approves if CRITICAL=0 and HIGH=0)
    ↓
CodeBuild Ephemeral Deploy:
    ├── Creates DEV Target Groups (nt548-dev-tg-*)
    ├── Injects ALB Listener Rules with Cookie: nt548-test=true
    ├── Runs ECS Fargate tasks with public IP
    ├── Executes automated smoke test
    └── Guaranteed Cleanup: Deletes DEV tasks, rules, and target groups
```

---

## 5. Frontend Stability & Root Cause Fix

### Root Causes Identified:
1. **Observed PROD crash**: ECS reported `EssentialContainerExited` (exit code 1), and the frontend CloudWatch stream contained `nginx: [emerg] unknown "user_service_host" variable`.
2. **Template variable collision**: The nginx image entrypoint applied `envsubst` to the whole template, so native lowercase nginx variables such as `$user_host` were removed before nginx parsed the generated configuration.
3. **Missing task environment**: The deployed frontend task definition did not contain the required `USER_SERVICE_*`, `PRODUCT_SERVICE_*`, or `ORDER_SERVICE_*` values.
4. **Invalid ECS upstream assumption**: The service names used by local Docker Compose are not DNS names in the current ECS design because Cloud Map/Service Connect is not enabled.

### Fixes Applied:
- **Lightweight `/health` Endpoint**:
  ```nginx
  location = /health {
      access_log off;
      default_type text/plain;
      add_header Content-Type text/plain;
      add_header X-NT548-Environment "${ENVIRONMENT}" always;
      return 200 "ok\n";
  }
  ```
- **Safe template rendering**: `NGINX_ENVSUBST_FILTER` permits only the seven uppercase deployment variables; the image build renders the template and runs `nginx -t`, preserving native nginx variables.
- **Architecture-correct upstreams**: Local Compose keeps service DNS names and ports; PROD sends API proxy traffic to the shared ALB DNS on port 80, where existing path rules route to the permanent backend target groups.
- **No localhost fallback**: Empty or invalid upstream configuration fails visibly instead of silently routing to the frontend container.
- **Secrets**: JWT and admin password values are injected from `nt548/app-secrets` through ECS secrets and a resource-scoped execution-role permission; they are not stored in task-definition environment blocks.
- **ECS Service Rolling Lifecycle**: Added `lifecycle { ignore_changes = [task_definition] }` to all 4 ECS services so Terraform apply never reverts application task revisions.
- **Rolling Configuration**: Configured `minimumHealthyPercent=100`, `maximumPercent=200`, a 60-second health grace period, and deployment-circuit-breaker rollback.

---

## 6. Terraform Structure & State Management

Terraform states are strictly isolated in S3 with server-side encryption, versioning, and native locking (`use_lockfile = true`):

```text
terraform/
├── bootstrap/                          # S3 State Bucket (nt548-terraform-state-<ACCOUNT_ID>)
├── modules/
│   ├── vpc/                            # VPC, 2 Public Subnets, IGW, Security Groups
│   ├── alb/                            # Shared ALB, Port 80 HTTP Listener, Target Groups
│   ├── ecr/                            # 8 ECR Repositories (4 DEV + 4 PROD, Immutable, Scan on Push)
│   ├── ecs/                            # ECS Fargate Cluster, Log Groups, Services & TaskDefs
│   ├── iam/                            # Least-Privilege IAM Roles & Policies
│   ├── sns/                            # SNS Topics for Infra and App approvals
│   ├── lambda-security-gate/           # Python 3.12 Lambda for DEV approval
│   ├── eventbridge/                    # EventBridge rule for ECR scan events
│   └── codebuild/                      # CodeBuild projects
│
└── environments/
    ├── shared/                         # VPC, ALB, ECR, IAM, S3 Artifacts
    │   └── backend.tf                  # key: shared/terraform.tfstate (use_lockfile = true)
    ├── dev/                            # DEV Pipeline & Lambda Gate
    │   └── backend.tf                  # key: dev/terraform.tfstate (use_lockfile = true)
    └── prod/                           # PROD Pipeline, CodeBuild, ECS Cluster & Services
        └── backend.tf                  # key: prod/terraform.tfstate (use_lockfile = true)
```

---

## 7. ECR Repository Architecture

| Repository Name | Environment | Tag Mutability | Scan on Push |
|---|---|---|---|
| `nt548-prod-frontend` | PROD | `IMMUTABLE` | `Enabled` |
| `nt548-prod-user` | PROD | `IMMUTABLE` | `Enabled` |
| `nt548-prod-product` | PROD | `IMMUTABLE` | `Enabled` |
| `nt548-prod-order` | PROD | `IMMUTABLE` | `Enabled` |
| `nt548-dev-frontend` | DEV | `IMMUTABLE` | `Enabled` |
| `nt548-dev-user` | DEV | `IMMUTABLE` | `Enabled` |
| `nt548-dev-product` | DEV | `IMMUTABLE` | `Enabled` |
| `nt548-dev-order` | DEV | `IMMUTABLE` | `Enabled` |

---

## 8. Checkov & Image Security Gates

1. **IaC Security (Checkov)**:
   - Scanned via `checkov --config-file .checkov.yml` in `nt548-prod-terraform-plan`; the config covers modules, shared, and PROD explicitly.
   - Blanket skips (`--soft-fail`) are strictly prohibited.
   - Legitimate design skips include detailed check IDs and justification comments.
2. **Container Security (ECR Scan)**:
   - Evaluated in `buildspec/prod-app-build.yml`.
   - The gate fails closed when any scan is missing, incomplete, or cannot be read.
   - Any image having `CRITICAL > 0` or `HIGH > 0` findings immediately halts the pipeline.
   - The approval artifact `ecr-scan-summary.json` records repository, immutable tag, digest, and counts for all four images.

---

## 9. ECS Rolling Deployment Strategy

PROD services use fixed, permanent Target Groups. No target groups are recreated during deployments.

```text
PROD Target Group (e.g. nt548-prod-tg-fe)
    │
    ├── Task Revision :N   (Healthy - serving traffic)
    └── Task Revision :N+1 (Starting -> Running -> Passing /health check)
            │
            ▼
    ALB shifts traffic to Revision :N+1
            │
            ▼
    Task Revision :N is deregistered and stopped
```

---

## 10. Hướng Dẫn Tái Sử Dụng & Triển Khai Trên AWS Account Mới (Multi-Account Setup Guide)

Dự án **NT548** được thiết kế theo chuẩn **Plug-and-Play (Cloud-Native Infrastructure as Code)**. Mọi tài nguyên hạ tầng, S3 bucket, ECR, IAM roles, Task definitions, và CI/CD pipelines đều tự động thích ứng với bất kỳ AWS Account ID nào mà **không cần sửa đổi code nguồn**.

### 📋 Bảng Kiểm Tra Các Giá Trị Cần Cấu Hình (Variables Checklist)

Khi triển khai trên AWS Account mới, bạn chỉ cần điều chỉnh các biến sau trong file `terraform.tfvars`:

| Biến | Môi Trường | Mô Tả | Nguồn Lấy / Cách Tạo |
|---|---|---|---|
| `aws_region` | All (`shared`, `dev`, `prod`) | Region triển khai (mặc định: `ap-southeast-1`) | Tùy chọn theo khu vực của bạn |
| `github_connection_arn` | All (`shared`, `dev`, `prod`) | ARN kết nối CodeConnections tới GitHub | Tạo trên AWS Console (xem Bước 2) |
| `github_repository` | `dev`, `prod` | Repository GitHub dạng `Owner/Repo` | Repository GitHub cá nhân của bạn sau khi fork |
| `approval_email` | `prod` | Email nhận thông báo phê duyệt thủ công | Email của quản trị viên/DevOps engineer |
| `app_image_tag` | `prod` | Image tag baseline ban đầu cho ECS | Mặc định `latest` hoặc commit SHA đầu tiên |

---

### 🚀 Hướng Dẫn Triển Khai Step-by-Step Cho Tài Khoản Mới

#### Bước 1: Chuẩn Bị Môi Trường Cục Bộ
Đảm bảo máy tính hoặc CloudShell đã cài đặt:
1. **AWS CLI** (đã cấu hình `aws configure` với quyền quản trị tài khoản mới):
   ```bash
   aws sts get-caller-identity
   # Kết quả trả về đúng Account ID mới của bạn
   ```
2. **Terraform** >= 1.5.0:
   ```bash
   terraform version
   ```
3. **Fork/Clone Repository** về máy:
   ```bash
   git clone https://github.com/<your-github-username>/NT548.git
   cd NT548
   ```

---

#### Bước 2: Tạo GitHub Connection Trên AWS (CodeConnections)
AWS CodePipeline yêu cầu quyền truy cập vào GitHub repo của bạn thông qua AWS CodeStar / CodeConnections:
1. Mở **AWS Management Console** ➔ Tìm dịch vụ **CodePipeline**.
2. Chọn menu bên trái **Settings** ➔ **Connections** ➔ Bấm nút **Create connection**.
3. Chọn provider: **GitHub** ➔ Đặt tên connection: `nt548-github-connection`.
4. Bấm **Connect to GitHub** ➔ Đăng nhập và chọn **Install a new app** để cấp quyền cho repository `NT548` của bạn.
5. Sau khi cấp quyền, bấm **Connect** để trạng thái của Connection chuyển thành `AVAILABLE`.
6. Sao chép chuỗi **Connection ARN** (Dạng: `arn:aws:codestar-connections:ap-southeast-1:<ACCOUNT_ID>:connection/<UUID>`).

---

#### Bước 3: Chạy Script Khởi Tạo Tự Động (Setup Bootstrap)
Dự án cung cấp sẵn kịch bản tự động hóa tại `scripts/setup-new-account.sh`:

```bash
chmod +x scripts/*.sh
bash scripts/setup-new-account.sh
```

Kịch bản sẽ tự động:
1. Lấy mã định danh **AWS Account ID** của tài khoản hiện tại.
2. Khởi tạo **S3 State Bucket** `nt548-terraform-state-<ACCOUNT_ID>` có bật Versioning và mã hóa AES256.
3. Tạo secret `nt548/app-secrets` trên **AWS Secrets Manager** chứa:
   ```json
   {
     "JWT_SECRET": "super-secret-jwt-key-change-in-production",
     "ADMIN_PASSWORD": "nt548-demo-password"
   }
   ```
4. Kiểm tra điều kiện cần và in ra hướng dẫn triển khai tiếp theo.

*(Ghi chú: Nếu muốn chạy thủ công bằng tay, xem mục **Tạo Thủ Công** phía dưới).*

---

#### Bước 4: Thiết Lập File Biến `terraform.tfvars`
Tại mỗi thư mục môi trường, sao chép file mẫu và điền thông tin của bạn:

1. **Shared (`terraform/environments/shared/`)**:
   ```bash
   cd terraform/environments/shared
   cp terraform.tfvars.example terraform.tfvars
   ```
   *Điền `github_connection_arn` đã lấy ở Bước 2.*

2. **DEV (`terraform/environments/dev/`)**:
   ```bash
   cd ../dev
   cp terraform.tfvars.example terraform.tfvars
   ```
   *Điền `github_connection_arn` và `github_repository`.*

3. **PROD (`terraform/environments/prod/`)**:
   ```bash
   cd ../prod
   cp terraform.tfvars.example terraform.tfvars
   ```
   *Điền `github_connection_arn`, `github_repository`, và `approval_email`.*

---

#### Bước 5: Triển Khai Hạ Tầng Theo Thứ Tự Chuẩn

> ⚠️ **Quy tắc quan trọng:** Phải triển khai `shared` trước để tạo VPC, ALB, ECR và IAM Roles cho `dev` và `prod` sử dụng.

1. **Triển khai `shared` (Hạ tầng dùng chung)**:
   ```bash
   cd terraform/environments/shared
   export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   terraform init -backend-config="bucket=nt548-terraform-state-${ACCOUNT_ID}"
   terraform apply
   ```
   *Nhập `yes` để hoàn tất.*

2. **Triển khai `dev` (DEV Pipeline & Automated Security Gate)**:
   ```bash
   cd ../dev
   terraform init -backend-config="bucket=nt548-terraform-state-${ACCOUNT_ID}"
   terraform apply
   ```
   *Nhập `yes` để hoàn tất.*

3. **Triển khai `prod` (PROD Pipeline, ECS Cluster & Services)**:
   ```bash
   cd ../prod
   terraform init -backend-config="bucket=nt548-terraform-state-${ACCOUNT_ID}"
   terraform apply
   ```
   *Nhập `yes` để hoàn tất.*

---

#### Bước 6: Kiểm Tra và Kích Hoạt CI/CD
1. **Kiểm tra nhánh `dev`**:
   - Push một commit lên nhánh `dev`:
     ```bash
     git checkout dev
     git commit --allow-empty -m "ci: trigger first dev pipeline run"
     git push origin dev
     ```
   - Quan sát trên AWS CodePipeline `nt548-dev-pipeline`: Build Docker images ➔ Quét ECR ➔ Lambda Auto-approval ➔ Triển khai tạm thời với Cookie routing ➔ Smoke test tự động ➔ Tự dọn dẹp sạch sẽ.
2. **Kiểm tra nhánh `main`**:
   - Merge `dev` vào `main` và push:
     ```bash
     git checkout main
     git merge dev
     git push origin main
     ```
   - Quan sát trên AWS CodePipeline `nt548-prod-pipeline`: Quét Checkov ➔ Phê duyệt Hạ tầng ➔ Build & Scan ECR ➔ Phê duyệt Triển khai ➔ Rolling update ECS Production.

---

## 11. Hướng Dẫn Cấu Hình Tên Miền Thủ Công (Manual Custom Domain Setup)

Mặc định, hệ thống dừng lại ở mức Application Load Balancer (ALB) cấp DNS công khai, **tuyệt đối không can thiệp Route 53 tự động** để bạn linh hoạt gắn tên miền của mình.

### Bước 1: Lấy DNS Của ALB Vừa Tạo
Sử dụng AWS CLI hoặc Terraform Output:
```bash
ALB_DNS=$(aws elbv2 describe-load-balancers --names nt548-shared-alb --region ap-southeast-1 --query "LoadBalancers[0].DNSName" --output text)
echo "ALB Public DNS: $ALB_DNS"
```

### Bước 2: Tạo Bản Ghi DNS Trỏ Về ALB
Trong dịch vụ quản lý DNS của bạn (Route 53 hoặc Cloudflare, Namecheap, v.v.):
* **Đối với AWS Route 53**:
  - Chọn Hosted Zone tương ứng tên miền của bạn.
  - Tạo bản ghi mới:
    - **Record name**: ví dụ `app.yourdomain.com` (hoặc `app.kiendev.site`).
    - **Record type**: `A`
    - **Alias**: Bật `Yes`
    - **Route traffic to**: *Alias to Application and Classic Load Balancer*
    - **Region**: `ap-southeast-1`
    - **Load Balancer**: Chọn `nt548-shared-alb` (`$ALB_DNS`)
* **Đối với Cloudflare / Nhà cung cấp DNS khác**:
  - Tạo bản ghi `CNAME`:
    - **Name**: `app`
    - **Target**: Giá trị `$ALB_DNS`
    - **Proxy status**: DNS only (hoặc Proxied nếu dùng SSL Cloudflare).

### Bước 3: (Tùy chọn) Bật HTTPS Với ACM SSL Certificate
1. Vào AWS Certificate Manager (ACM) tại region `ap-southeast-1` ➔ Bấm **Request a certificate** cho tên miền của bạn (ví dụ `app.yourdomain.com`).
2. Thêm bản ghi CNAME xác thực DNS do ACM cung cấp.
3. Sau khi ACM chuyển trạng thái sang **Issued**, vào file `terraform/environments/shared/main.tf`:
   ```hcl
   module "alb" {
     source            = "../../modules/alb"
     # ...
     certificate_arn   = "<your-acm-certificate-arn>" # Điền ARN tại đây
   }
   ```
4. Chạy `terraform apply` trong `terraform/environments/shared` để kích hoạt HTTPS listener port 443.

---

## 12. Verification & Smoke Testing (Kiểm Thử Nghiệm Thu)

Sau khi hoàn tất triển khai, bạn có thể kiểm thử toàn bộ hệ thống bằng lệnh `curl`:

```bash
# 1. Lấy địa chỉ ALB DNS
ALB=$(aws elbv2 describe-load-balancers --names nt548-shared-alb --region ap-southeast-1 --query "LoadBalancers[0].DNSName" --output text)

# 2. Kiểm tra Health Endpoint của Frontend
curl -i http://$ALB/health
# Kỳ vọng: HTTP/1.1 200 OK (body: "ok", Header: X-NT548-Environment: prod)

# 3. Kiểm tra Web Frontend SPA
curl -i http://$ALB/
# Kỳ vọng: HTTP/1.1 200 OK (HTML trang chủ Console NT548)

# 4. Đăng nhập qua Auth Service (Node.js/Express - Port 5001)
LOGIN_RES=$(curl -s -X POST http://$ALB/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@nt548.local","password":"nt548-demo"}')
echo "$LOGIN_RES"

TOKEN=$(echo "$LOGIN_RES" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
echo "JWT Token: $TOKEN"

# 5. Lấy danh sách sản phẩm từ Product Service (Python/Flask - Port 5002)
curl -s -H "Authorization: Bearer $TOKEN" http://$ALB/api/products
# Kỳ vọng: Danh sách JSON 4 sản phẩm mẫu

# 6. Lấy danh sách đơn hàng từ Order Service (Node.js/Express - Port 5003)
curl -s -H "Authorization: Bearer $TOKEN" http://$ALB/api/orders
# Kỳ vọng: Danh sách JSON 3 đơn hàng mẫu
```

### Kiểm thử DEV Ephemeral Stack (Cookie Routing):
```bash
# Khi chạy DEV test hoặc muốn thử nghiệm endpoint DEV:
curl -i -H "Cookie: nt548-test=true" http://$ALB/health
```

