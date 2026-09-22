# NT548 — AWS ECS Microservices & Multi-Environment DevSecOps

Nền tảng microservices chạy trên Amazon ECS Fargate, được quản lý bằng Terraform và triển khai qua hai AWS CodePipeline độc lập:

- `dev`: build, test, scan, triển khai môi trường tạm thời, smoke test và tự dọn dẹp.
- `main`: lập kế hoạch hạ tầng, phê duyệt thủ công, build/scan image và rolling deployment lên PROD.

Repository được thiết kế để triển khai lặp lại trên **một AWS account khác** mà không dùng lại state, ARN hoặc tài nguyên của account hiện tại. Mỗi account có state bucket, CodeConnections, IAM roles, ECR repositories và pipelines riêng.

> Đây là kiến trúc **production-like phục vụ học tập/lab**. Cấu hình mặc định ưu tiên chi phí thấp: public subnets, Fargate public IP, ALB HTTP và một task cho mỗi PROD service. Xem [Giới hạn và hướng nâng cấp](#giới-hạn-và-hướng-nâng-cấp) trước khi dùng cho production thật.

## Kiến trúc

```text
Developer
   │ git push dev / main
   ▼
GitHub App + AWS CodeConnections
   │ WebhookV2
   ├──────────────────────────────┐
   ▼                              ▼
DEV CodePipeline                  PROD CodePipeline
   │                              │
   ├─ Unit tests                  ├─ Terraform fmt / validate
   ├─ Docker build                ├─ Checkov + saved tfplan
   ├─ ECR scan                    ├─ Manual infrastructure approval
   ├─ Automated security gate     ├─ Apply exact approved plan
   ├─ Ephemeral ECS deployment    ├─ Unit tests + Docker build
   ├─ Cookie-routed smoke tests   ├─ ECR scan
   └─ Guaranteed cleanup          ├─ Manual application approval
                                  └─ ECS rolling deployment
                                                   │
Internet ──► Shared ALB ──► ECS Fargate ──► CloudWatch Logs
                    │
                    ├─ Frontend :80
                    ├─ User     :5001
                    ├─ Product  :5002
                    └─ Order    :5003
```

### Application services

| Service | Runtime | Port | Responsibility |
|---|---|---:|---|
| `frontend` | Nginx | 80 | Static UI, health endpoint và reverse proxy |
| `be-user-service` | Node.js/Express | 5001 | Login, password hashing và JWT issuance |
| `be-product-service` | Python/Flask | 5002 | Product API được bảo vệ bằng JWT |
| `be-order-service` | Node.js/Express | 5003 | Order API được bảo vệ bằng JWT |

## CI/CD flow

### DEV — ephemeral validation

```text
push dev
  → Source (WebhookV2)
  → Unit tests + immutable image tag = commit SHA
  → Push 4 DEV images to ECR
  → ECR vulnerability scans
  → Lambda gate: CRITICAL=0 và HIGH=0
  → Create temporary ECS services/target groups/listener rules
  → Wait until all services are stable
  → Cookie-routed API smoke tests
  → Cleanup rules, target groups và services
```

DEV traffic dùng header `Cookie: nt548-test=true`, vì vậy có thể kiểm thử trên shared ALB mà không ghi đè default PROD routes.

### PROD — infrastructure and application promotion

```text
push main
  → Source (WebhookV2)
  → Terraform format, validate, Checkov and plan
  → Manual approval of the saved plan
  → Apply the exact approved tfplan
  → Unit tests + build 4 images
  → ECR scan gate: CRITICAL=0 và HIGH=0
  → Manual application approval
  → Four native ECS rolling deploy actions
```

Pipeline dùng `V2` + `QUEUED`, explicit branch filters và `DetectChanges=false`. Điều này tránh chạy trùng giữa default source detection và V2 Git trigger.

## Repository layout

```text
.
├── frontend/                       # Nginx SPA
├── be-user-service/                # Node.js authentication API
├── be-product-service/             # Python product API
├── be-order-service/               # Node.js order API
├── buildspec/                      # CodeBuild phase definitions
├── scripts/                        # Build, scan, ephemeral deploy and cleanup
├── lambda/security_gate/           # Automated ECR scan approval gate
└── terraform/
    ├── bootstrap/                  # Per-account remote-state S3 bucket
    ├── environments/
    │   ├── shared/                 # VPC, ALB, ECR, IAM and artifact bucket
    │   ├── dev/                    # DEV pipeline and ephemeral validation
    │   └── prod/                   # PROD ECS and seven-stage pipeline
    └── modules/                    # Reusable Terraform modules
```

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
| Availability Zones | Tự chọn hai AZ khả dụng trong Region nếu không override |
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
| `availability_zones` | VPC module | Optional AZ override; mặc định tự phát hiện |

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
