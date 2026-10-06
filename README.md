# NT548 — AWS ECS Microservices & Multi-Environment DevSecOps (Infrastructure)

> 📌 **Phân tách Repository**:
> - **Repository Hạ tầng (Infra)**: [Jonnysilverfang/NT548](https://github.com/Jonnysilverfang/NT548) (Repository hiện tại)
> - **Repository Ứng dụng (Application)**: [Kien-devops/NT548-APP](https://github.com/Kien-devops/NT548-APP)

Nền tảng microservices chạy trên Amazon ECS Fargate, được quản lý bằng Terraform và triển khai qua các AWS CodePipeline độc lập:

- `nt548-dev-pipeline`: build, test, scan, triển khai môi trường tạm thời, smoke test và tự dọn dẹp (theo dõi `Kien-devops/NT548-APP:dev`).
- `nt548-prod-infra-pipeline`: lập kế hoạch hạ tầng Terraform, phê duyệt thủ công, apply (theo dõi `Jonnysilverfang/NT548:main`).
- `nt548-prod-app-pipeline`: build/scan ECR, phê duyệt thủ công và rolling deployment lên ECS PROD (theo dõi `Kien-devops/NT548-APP:main`).

> Đây là kiến trúc **production-like phục vụ học tập/lab**. Cấu hình mặc định ưu tiên chi phí thấp: public subnets, Fargate public IP, ALB HTTP và một task cho mỗi PROD service. Xem [Giới hạn và hướng nâng cấp](#giới-hạn-và-hướng-nâng-cấp) trước khi dùng cho production thật.

## Kiến trúc phân tách 2 Repository

Kiến trúc được chia tách hoàn toàn giữa **Hạ tầng (Infra as Code)** và **Ứng dụng (Microservices Application)**, được liên kết qua AWS CodeConnections và 3 CodePipelines độc lập:

```text
                                     Developer
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │ git push (Infra)                              │ git push (App)
                 ▼                                               ▼
       Repo Infra: NT548                                Repo App: NT548-APP
    (Jonnysilverfang/NT548)                           (Kien-devops/NT548-APP)
                 │                                               │
                 │ branch main                                   ├──────────────────────────────┐
                 ▼                                               │ branch dev                   │ branch main
   AWS CodeConnections (WebhookV2)                               ▼                              ▼
                 │                                 AWS CodeConnections (WebhookV2) AWS CodeConnections (WebhookV2)
                 ▼                                               │                              │
     nt548-prod-infra-pipeline                                   ▼                              ▼
   ┌───────────────────────────┐                         nt548-dev-pipeline             nt548-prod-app-pipeline
   │ 1. Source (NT548:main)    │                       ┌────────────────────┐         ┌─────────────────────────┐
   │ 2. Terraform Plan&Checkov │                       │ 1. Source (dev)    │         │ 1. Source (main)        │
   │ 3. Manual Infra Approval  │                       │ 2. Unit Tests      │         │ 2. Unit Tests           │
   │ 4. Terraform Apply        │                       │ 3. Build & Scan ECR│         │ 3. Build & Scan ECR     │
   └─────────────┬─────────────┘                       │ 4. Security Gate   │         │ 4. Manual App Approval  │
                 │                                     │ 5. Ephemeral ECS   │         │ 5. ECS Rolling Deploy   │
                 │                                     │ 6. Smoke Tests     │         └────────────┬────────────┘
                 │ Provision / Update                  │ 7. Auto Cleanup    │                      │ Deploy to
                 ▼                                     └────────────────────┘                      ▼
     Shared AWS Infrastructure ◄───────────────────────────────────────────────────────────────────┘
     (VPC, Subnets, ECR, IAM, ALB, ECS Cluster: nt548-cluster)
                 │
                 ├──► Shared ALB (Internet-facing HTTP :80)
                 │        ├─ Path /           ──► Frontend Service (:80)
                 │        ├─ Path /api/users  ──► User Service     (:5001)
                 │        ├─ Path /api/products ─► Product Service  (:5002)
                 │        └─ Path /api/orders ──► Order Service    (:5003)
                 │
                 └──► ECS Fargate Tasks ──► CloudWatch Logs
```

### Application services (Lưu trữ tại repository [NT548-APP](https://github.com/Kien-devops/NT548-APP))

| Service | Runtime | Port | Responsibility |
|---|---|---:|---|
| `frontend` | Nginx SPA | 80 | Static UI, health endpoint và reverse proxy |
| `be-user-service` | Node.js/Express | 5001 | Login, password hashing và JWT issuance |
| `be-product-service` | Python/Flask | 5002 | Product API được bảo vệ bằng JWT |
| `be-order-service` | Node.js/Express | 5003 | Order API được bảo vệ bằng JWT |

---

## Chi tiết 3 Pipelines CI/CD

### 1. `nt548-prod-infra-pipeline` (Quản lý Hạ tầng)
- **Repository nguồn:** `Jonnysilverfang/NT548` (nhánh `main`)
- **Quy trình thực thi:**
  ```text
  push main (NT548)
    → Source (WebhookV2 qua AWS CodeConnections)
    → InfraPlan: Terraform fmt, validate, Checkov SAST scan, tạo và lưu tfplan
    → InfraApproval: Quản trị viên nhận thông báo SNS và review tfplan
    → InfraApply: Áp dụng chính xác tfplan đã duyệt lên môi trường AWS
  ```

### 2. `nt548-dev-pipeline` (Kiểm thử Ứng dụng Tự động)
- **Repository nguồn:** `Kien-devops/NT548-APP` (nhánh `dev`)
- **Quy trình thực thi:**
  ```text
  push dev (NT548-APP)
    → Source (WebhookV2 qua AWS CodeConnections)
    → BuildAndScan: Unit tests + Build 4 Docker images với tag commit SHA + Push DEV ECR
    → SecurityGate: AWS Lambda tự động kiểm tra ECR scan (bắt buộc CRITICAL=0, HIGH=0)
    → DeployAndTest: Tạo ECS services/target groups tạm thời (Cookie: nt548-test=true)
    → Chạy toàn bộ bộ API Smoke tests và tự động dọn dẹp (cleanup)
  ```

### 3. `nt548-prod-app-pipeline` (Triển khai Ứng dụng Production)
- **Repository nguồn:** `Kien-devops/NT548-APP` (nhánh `main`)
- **Quy trình thực thi:**
  ```text
  push main (NT548-APP)
    → Source (WebhookV2 qua AWS CodeConnections)
    → AppBuild: Unit tests + Build 4 Docker images + Push PROD ECR + Quét lỗ hổng
    → ProductionApproval: Phê duyệt thủ công dựa trên kết quả ECR scan (C=0, H=0)
---

## Cơ chế Change Detection & Thành phần CI/CD Tái sử dụng

### 1. Change Detection cho Hạ tầng (`scripts/detect-infra-changes.sh`)
Pipeline hạ tầng được trang bị bộ nhận diện thay đổi Git thông minh nhằm tối ưu chi phí CodeBuild và thời gian chờ:
- **Tài liệu thuần túy (`README.md`, `*.md`, `docs/*`)**: Đánh dấu `INFRA_CHANGED=false` & `DOCS_ONLY=true` -> **Bỏ qua (SKIP)** các bước `terraform plan` và `terraform apply`.
- **Hạ tầng PROD (`terraform/environments/prod/*`)**: Đánh dấu `PROD_CHANGED=true` -> Kích hoạt quy trình plan/apply cho môi trường PROD.
- **Hạ tầng DEV (`terraform/environments/dev/*`)**: Đánh dấu `DEV_CHANGED=true`.
- **Modules dùng chung (`terraform/modules/*`, `terraform/environments/shared/*`, `.checkov.yml`)**: Tự động đánh dấu toàn bộ môi trường phụ thuộc (`PROD_CHANGED=true`, `DEV_CHANGED=true`) để chạy plan đầy đủ mà không bỏ sót ảnh hưởng.
- **Nguyên tắc an toàn Terraform (Terraform Safety)**: Tuyệt đối **không** dùng `terraform apply -target=module.*` trong CI/CD. Toàn bộ dependency graph của Terraform được duy trì nguyên vẹn ở cấp độ Root Module.

### 2. Thành phần Runner tái sử dụng (`scripts/terraform-pipeline.sh`)
Thay vì lặp lại các lệnh trong từng phase buildspec, quy trình được đóng gói thành script chuẩn hóa:
- `./scripts/terraform-pipeline.sh fmt`: Kiểm tra định dạng HCL trên toàn bộ repo.
- `./scripts/terraform-pipeline.sh checkov`: Quét phân tích tĩnh bảo mật IaC (SAST).
- `./scripts/terraform-pipeline.sh validate <env>`: Khởi tạo backend và kiểm tra tính hợp lệ cú pháp.
- `./scripts/terraform-pipeline.sh plan <env>`: Tạo và lưu file thực thi `tfplan` & `tfplan.txt`.
- `./scripts/terraform-pipeline.sh apply <env>`: Áp dụng chính xác file `tfplan` đã được phê duyệt qua SNS.

---

## Các kịch bản kiểm thử mẫu (Example Scenarios)

### Kịch bản A: Chỉ sửa code `be-product-service/app.py` (Repo App)
- **Hạ tầng (`NT548`)**: Không bị kích hoạt (hoặc skip nếu push nhầm vào repo hạ tầng).
- **Ứng dụng (`NT548-APP`)**:
  - `FRONTEND_CHANGED=false`, `USER_CHANGED=false`, `ORDER_CHANGED=false`.
  - **Duy nhất `PRODUCT_CHANGED=true`**.
  - Chỉ chạy test, build Docker image, push ECR và quét lỗ hổng cho `be-product-service`.
  - Các service khác giữ nguyên image hiện tại, tiết kiệm > 75% tài nguyên CodeBuild.

### Kịch bản B: Chỉ sửa tài liệu `README.md` hoặc `*.md`
- **Hạ tầng (`NT548`)**: Change detector xác định `DOCS_ONLY=true` -> **SKIP** toàn bộ Terraform Plan & Apply. Không sinh chi phí hay thông báo approval SNS rác.
- **Ứng dụng (`NT548-APP`)**: Change detector xác định `DOCS_ONLY=true` -> **SKIP** toàn bộ Test, Build và Deploy.

### Kịch bản C: Thay đổi module Terraform chung (`terraform/modules/vpc/*` hoặc `modules/alb/*`)
- **Hạ tầng (`NT548`)**: Change detector xác định `MODULES_CHANGED=true` -> Tự động kích hoạt Terraform Plan cho mọi môi trường tiêu thụ module để bảo đảm an toàn toàn diện cho hệ thống.

### Kịch bản D: Thay đổi script CI/CD dùng chung (`scripts/*`, `buildspec/*`)
- **Hạ tầng (`NT548`)**: Chạy kiểm tra và lập kế hoạch cho toàn bộ các môi trường hạ tầng.
- **Ứng dụng (`NT548-APP`)**: Đánh dấu `SHARED_CHANGED=true` -> Toàn bộ 4 microservices được kiểm thử và validate đồng thời để loại trừ nguy cơ hỏng pipeline chung.

## Cấu trúc Repository Hạ tầng (NT548)

```text
.
├── buildspec/                      # CodeBuild phase definitions cho hạ tầng
│   ├── prod-infra-plan.yml         # Terraform plan & Checkov security scan
│   └── prod-infra-apply.yml        # Terraform apply approved tfplan
├── lambda/security_gate/           # Mã nguồn Lambda Security Gate tự động duyệt ECR scan
└── terraform/
    ├── bootstrap/                  # Remote-state S3 bucket cho từng AWS account
    ├── environments/
    │   ├── shared/                 # VPC, ALB, ECR repositories, IAM roles, S3 artifacts
    │   ├── dev/                    # DEV pipeline và cấu hình Lambda Gate
    │   └── prod/                   # PROD ECS services và 2 pipelines (Infra + App)
    └── modules/                    # Reusable Terraform modules (alb, ecr, ecs, iam, vpc, sns)
```

> 💡 *Toàn bộ mã nguồn ứng dụng (microservices, Dockerfiles, docker-compose, scripts kiểm thử) được lưu trữ tại [Kien-devops/NT548-APP](https://github.com/Kien-devops/NT548-APP).*

## Tái sử dụng trên AWS account khác

### Portability checklist

| Concern | Implementation |
|---|---|
| AWS account ID | Được lấy bằng STS/Terraform caller identity, không nhập tay |
| Remote state | Bucket riêng: `nt548-terraform-state-<ACCOUNT_ID>` |
| Backend safety | Partial backend configuration; bắt buộc truyền bucket và Region khi `terraform init` |
| Artifact bucket | Tự sinh theo account: `nt548-artifacts-<ACCOUNT_ID>` |
| GitHub access | Connection riêng, cùng Region với pipeline và phải được repo owner authorize |
| IAM | Connection ARN và repository được truyền bằng biến, không dùng wildcard cho `UseConnection` |
| Availability Zones | Bootstrap chọn rồi pin hai AZ khả dụng, tránh subnet drift khi AWS bổ sung AZ |
| Secrets | Giá trị nằm trong Secrets Manager, không ghi vào Terraform state hoặc Git |
| Initial PROD images | Bootstrap với `service_desired_count=0`, sau đó build image và scale lên `1` |
| Pipeline Terraform variables | Được lưu trong CodeBuild dưới dạng `TF_VAR_*` từ lần apply đầu |

Đây là **independent deployment per account**, không phải một pipeline trung tâm deploy cross-account. Thiết kế cross-account thật cần thêm KMS key policy, artifact-bucket policy và target deployment role.

### Prerequisites

- AWS CLI v2 đã đăng nhập đúng account.
- Terraform `>= 1.5`.
- Bash, Python 3 và OpenSSL. Trên Windows dùng Git Bash hoặc WSL.
- GitHub repository có hai branch `dev` và `main`.
- GitHub repository owner có quyền cài **AWS Connector for GitHub**.
- Quyền AWS đủ để tạo S3, IAM, VPC, ALB, ECR, ECS, CodeBuild, CodePipeline, Lambda, EventBridge, SNS và Secrets Manager.

### 1. Create the regional GitHub connection

Trong AWS Console, chọn đúng Region sẽ chạy pipeline, mặc định là Singapore `ap-southeast-1`:

1. Mở **Developer Tools → Settings → Connections**.
2. Tạo GitHub connection.
3. Chọn **Install a new app** hoặc app installation do repository owner quản lý.
4. Trong GitHub App settings, cấp quyền cho repository cần triển khai.
5. Chờ trạng thái connection thành `AVAILABLE`.
6. Ghi lại ARN dạng `arn:aws:codeconnections:<REGION>:<ACCOUNT_ID>:connection/<ID>`.

Source actions không hỗ trợ cross-Region. Connection và CodePipeline phải ở cùng Region.

### 2. Export account-specific inputs

```bash
export AWS_REGION="ap-southeast-1"
export GITHUB_CONNECTION_ARN="arn:aws:codeconnections:ap-southeast-1:123456789012:connection/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export GITHUB_REPOSITORY="your-owner/NT548"
export APPROVAL_EMAIL="platform-team@example.com"

# Optional
export PROJECT_NAME="NT548"
export DOMAIN_NAME="example.invalid"
export APP_IMAGE_TAG="bootstrap"
```

`GITHUB_REPOSITORY` phân biệt chữ hoa/thường và phải khớp repository đã cấp cho GitHub App.

### 3. Bootstrap the account

```bash
bash scripts/setup-new-account.sh
```

Script thực hiện các bước fail-closed:

- xác minh AWS account và Region;
- kiểm tra connection ARN thuộc đúng account/Region và có trạng thái `AVAILABLE`;
- tạo state bucket mã hóa, versioning và public-access block;
- tạo `nt548/app-secrets` với credentials ngẫu nhiên nếu secret chưa tồn tại;
- sinh ba file `terraform.tfvars` cục bộ, được `.gitignore` bảo vệ;
- đặt PROD `service_desired_count=0` cho lần bootstrap đầu.

### 4. Deploy in dependency order

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="nt548-terraform-state-${ACCOUNT_ID}"

terraform -chdir=terraform/environments/shared init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform/environments/shared plan -out=tfplan
terraform -chdir=terraform/environments/shared apply tfplan

terraform -chdir=terraform/environments/dev init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform/environments/dev plan -out=tfplan
terraform -chdir=terraform/environments/dev apply tfplan

terraform -chdir=terraform/environments/prod init -reconfigure \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}"
terraform -chdir=terraform/environments/prod plan -out=tfplan
terraform -chdir=terraform/environments/prod apply tfplan
```

Không apply nếu plan chứa tài nguyên ngoài account/Region dự kiến hoặc tham chiếu connection ARN của account khác.

### 5. Seed PROD images safely

Lần apply đầu tạo PROD services với desired count bằng `0`; điều này loại bỏ lỗi ECS cố pull image chưa tồn tại.

1. Push một commit lên `main` để pipeline build bốn PROD images.
2. Review và approve infrastructure plan.
3. Review ECR scan evidence rồi approve application stage.
4. Đổi trong `terraform/environments/prod/terraform.tfvars`:

   ```hcl
   service_desired_count = 1
   ```

5. Chạy lại `terraform plan` và `terraform apply` cho PROD.
6. Xác nhận bốn ECS services có `runningCount == desiredCount == 1` và target health là `healthy`.

## Configuration reference

| Variable | Environment | Description |
|---|---|---|
| `aws_region` | shared/dev/prod | Region của toàn bộ deployment |
| `github_connection_arn` | shared/dev/prod | Regional CodeConnections ARN |
| `github_repository` | shared/dev/prod | Case-sensitive `Owner/Repo` |
| `approval_email` | prod | SNS subscriber cho manual approvals |
| `app_image_tag` | prod | Baseline task-definition tag khi bootstrap |
| `service_desired_count` | prod | `0` khi chưa có image, `1+` sau bootstrap |
| `project_name` | shared | Project tag prefix |
| `availability_zones` | shared/VPC module | Hai AZ được bootstrap phát hiện và ghi cố định vào `terraform.tfvars` |

Các giá trị trong `terraform.tfvars.example` chỉ là mẫu. Không commit `terraform.tfvars`, secrets hoặc plan files.

## Security controls

- CodeConnections sử dụng GitHub App; không lưu personal access token.
- Pipeline roles chỉ có `codeconnections:UseConnection` trên ARN được cấu hình và repository được chỉ định.
- PROD CodeBuild có `PassConnection` trên đúng connection ARN.
- Application credentials lấy từ Secrets Manager qua ECS task execution role.
- ECR repositories bật immutable tags và scan-on-push.
- DEV Lambda chỉ approve khi đủ bốn image cùng commit tag và không có HIGH/CRITICAL findings.
- PROD thay đổi hạ tầng và application deployment đều có manual approval riêng.
- Terraform state dùng S3 encryption, versioning và native lockfile.

> Một số policy của lab vẫn rộng hơn least privilege lý tưởng để hỗ trợ Terraform và ephemeral resources. Với production, tách provisioning role khỏi build role, giới hạn `iam:PassRole`, S3, ECS và CodeBuild theo ARN cụ thể, đồng thời chạy IAM Access Analyzer.

## Verification

### Static validation

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform/environments/shared validate
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/prod validate
checkov --config-file .checkov.yml
```

### Confirm automatic triggers

Sau khi push, execution phải có trigger type `WebhookV2`, không phải `StartPipelineExecution`:

```bash
aws codepipeline list-pipeline-executions \
  --pipeline-name nt548-dev-pipeline \
  --region "$AWS_REGION" \
  --max-results 1
```

Lặp lại với `nt548-prod-pipeline` cho branch `main`.

### Application smoke test

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names nt548-shared-alb \
  --region "$AWS_REGION" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

curl -fsS "http://${ALB_DNS}/health"
curl -fsS -H 'Cookie: nt548-test=true' "http://${ALB_DNS}/health"
```

DEV smoke tests còn kiểm tra login, products và orders APIs trước khi cleanup.

## Rollback and recovery

- **Terraform:** không approve khi `tfplan.txt` chứa thay đổi ngoài dự kiến. State versioning hỗ trợ phục hồi nhưng phải điều tra drift trước khi rollback state.
- **Application:** ECS rolling deployment circuit breaker rollback task revision khi replacement tasks không ổn định.
- **Pipeline:** `QUEUED` giữ thứ tự commit. Không đổi execution mode khi còn executions đang chờ.
- **DEV cleanup:** cleanup chạy trong `post_build`; script phải idempotent để retry an toàn.
- **Connection failure:** kiểm tra Region, trạng thái `AVAILABLE`, GitHub App repository access, IAM namespace `codeconnections:*` và exact ARN.

## Cost model

Các thành phần phát sinh chi phí chính:

- Application Load Balancer chạy liên tục;
- bốn PROD Fargate tasks khi `service_desired_count=1`;
- CodeBuild minutes, ECR storage/scanning, CloudWatch Logs và Secrets Manager;
- data transfer/public IPv4 tùy cấu hình và Region.

DEV resources là ephemeral nhưng shared ALB, ECR, logs, state bucket và PROD fleet không tự xóa.

## Cleanup

Thứ tự destroy an toàn:

```text
prod → dev → shared
```

State bucket có `prevent_destroy=true` và không bị xóa tự động. Chỉ xóa sau khi đã xác minh các environment states không còn cần cho rollback/audit. Không xóa connection dùng chung nếu account còn pipeline khác sử dụng.

## Giới hạn và hướng nâng cấp

Thiết kế hiện tại chưa đáp ứng production HA đầy đủ:

- một task cho mỗi service không chịu được AZ/task failure mà không gián đoạn;
- public subnets và public task IP được dùng để tránh chi phí NAT Gateway;
- ALB mặc định dùng HTTP, chưa bắt buộc ACM/TLS;
- không có WAF, autoscaling, tracing, multi-Region DR hoặc centralized observability;
- không có persistent production database trong Terraform hiện tại;
- Terraform provisioning role còn cần thu hẹp thêm quyền.

Hướng nâng cấp đề xuất: private subnets + VPC endpoints/NAT, desired count tối thiểu `2`, Application Auto Scaling, HTTPS-only listener, AWS WAF, CloudWatch alarms, OpenTelemetry/X-Ray, backup policy và cross-account deployment roles tách biệt.

## Troubleshooting quick reference

| Symptom | Check first |
|---|---|
| Push không chạy pipeline | Connection cùng Region, `AVAILABLE`, GitHub App repo access, trigger `sourceActionName` |
| Source `AccessDenied` | `codeconnections:UseConnection`, exact ARN và `FullRepositoryId` condition |
| Terraform dùng nhầm state | Chạy lại `terraform init -reconfigure` với bucket chứa current account ID |
| ECS service không start ở account mới | Giữ desired count `0` cho đến khi image tag tồn tại trong PROD ECR |
| DEV smoke test không có endpoint | Kiểm tra `BASE_URL` hoặc ALB `nt548-shared-alb` trong đúng Region |
| Pipeline chạy hai lần | Dùng explicit V2 trigger và `DetectChanges=false` |
| PROD đứng ở approval | Đây là hành vi dự kiến; review plan/scan evidence trước khi approve |

---

Project: **NT548 — DevOps Technologies and Applications**

Default Region: **Asia Pacific (Singapore), `ap-southeast-1`**
