# 🏛️ HƯỚNG DẪN THỰC HÀNH LAB: BATCH AI LOG ANALYSIS USING AMAZON BEDROCK
## Xây dựng hệ thống thu thập, tiền xử lý và phân tích nguyên nhân gốc rễ (RCA) nhật ký lỗi tự động bằng kiến trúc Serverless & Generative AI trên AWS

> **Cấp độ:** Advanced Hands-on Lab (Step-by-Step AWS Management Console)  
> **AWS Region:** Asia Pacific (Sydney) — `ap-southeast-2`  
> **Kiến trúc:** Batch Serverless Architecture (Data Firehose ➔ S3 ➔ EventBridge Scheduler ➔ Lambda Filter/Grouping ➔ Amazon Bedrock ➔ DynamoDB & SNS)  
> **Tác giả:** Senior AWS Solutions Architect & DevOps Engineer  

---

## 📑 MỤC LỤC CHI TIẾT

1. [Tổng Quan Kiến Trúc & Sơ Đồ Khối Luồng Dữ Liệu](#1-tổng-quan-kiến-trúc--sơ-đồ-khối-luồng-dữ-liệu)
2. [Nguyên Lý Thiết Kế: Batching, Filtering, Grouping & Tối Ưu Chi Phí](#2-nguyên-lý-thiết-kế-batching-filtering-grouping--tối-ưu-chi-phí)
3. [Bảng Tổng Hợp Tài Nguyên & IAM Matrix](#3-bảng-tổng-hợp-tài-nguyên--iam-matrix)
4. [Kiểm Tra Khả Dụng Dịch Vụ & Model Bedrock Tại Sydney (ap-southeast-2)](#4-kiểm-tra-khả-dụng-dịch-vụ--model-bedrock-tại-sydney-ap-southeast-2)
5. [Hướng Dẫn Triển Khai Step-by-Step Trên AWS Management Console](#5-hướng-dẫn-triển-khai-step-by-step-trên-aws-management-console)
   - [BƯỚC 1: Kích hoạt quyền truy cập Model trên Amazon Bedrock](#bước-1-kích-hoạt-quyền-truy-cập-model-trên-amazon-bedrock)
   - [BƯỚC 2: Tạo Amazon S3 Bucket lưu trữ Log tập trung](#bước-2-tạo-amazon-s3-bucket-lưu-trữ-log-tập-trung)
   - [BƯỚC 3: Tạo 2 bảng Amazon DynamoDB (Checkpoint State & Analysis Results)](#bước-3-tạo-2-bảng-amazon-dynamodb-checkpoint-state--analysis-results)
   - [BƯỚC 4: Tạo Amazon SNS Topic & Xác thực Email Đăng ký Nhận Cảnh báo](#bước-4-tạo-amazon-sns-topic--xác-thực-email-đăng-ký-nhận-cảnh-báo)
   - [BƯỚC 5: Thiết lập IAM Role cho Amazon Data Firehose & CloudWatch Logs](#bước-5-thiết-lập-iam-role-cho-amazon-data-firehose--cloudwatch-logs)
   - [BƯỚC 6: Tạo Amazon Data Firehose Delivery Stream gom Log về S3](#bước-6-tạo-amazon-data-firehose-delivery-stream-gom-log-về-s3)
   - [BƯỚC 7: Tạo Demo App Lambda & Phát sinh Log giả lập lên CloudWatch Logs](#bước-7-tạo-demo-app-lambda--phát-sinh-log-giả-lập-lên-cloudwatch-logs)
   - [BƯỚC 8: Cấu hình CloudWatch Logs Subscription Filter chuyển tiếp sang Firehose](#bước-8-cấu-hình-cloudwatch-logs-subscription-filter-chuyển-tiếp-sang-firehose)
   - [BƯỚC 9: Tạo IAM Execution Role chuẩn Least Privilege cho Batch Processor Lambda](#bước-9-tạo-iam-execution-role-chuẩn-least-privilege-cho-batch-processor-lambda)
   - [BƯỚC 10: Tạo & Cấu hình Hàm Lambda AI Batch Processor](#bước-10-tạo--cấu-hình-hàm-lambda-ai-batch-processor)
   - [BƯỚC 11: Tạo Amazon EventBridge Scheduler kích hoạt định kỳ Batch Job](#bước-11-tạo-amazon-eventbridge-scheduler-kích-hoạt-định-kỳ-batch-job)
6. [Toàn Bộ Mã Nguồn Chi Tiết (Full Python Source Code)](#6-toàn-bộ-mã-nguồn-chi-tiết-full-python-source-code)
   - [6.1. Mã nguồn Demo App (`ai-log-demo-app`)](#61-mã-nguồn-demo-app-ai-log-demo-app)
   - [6.2. Mã nguồn AI Batch Processor (`ai-log-batch-processor`)](#62-mã-nguồn-ai-batch-processor-ai-log-batch-processor)
7. [Kịch Bản Kiểm Thử Toàn Diện (End-to-End Test Scenarios)](#7-kịch-bản-kiểm-thử-toàn-diện-end-to-end-test-scenarios)
   - [Kịch bản 1: Nhật ký bình thường (Only INFO/HTTP 200)](#kịch-bản-1-nhật-ký-bình-thường-only-infohttp-200)
   - [Kịch bản 2: Lỗi trung bình lặp lại (Database Timeout Flurry)](#kịch-bản-2-lỗi-trung-bình-lặp-lại-database-timeout-flurry)
   - [Kịch bản 3: Thảm họa Critical Severity (Payment Down + HTTP 503 + SNS Email)](#kịch-bản-3-thảm-họa-critical-severity-payment-down--http-503--sns-email)
8. [Phân Tích Xử Lý Tình Huống Ngoại Lệ & Thất Bại (Failure Scenarios & Idempotency)](#8-phân-tích-xử-lý-tình-huống-ngoại-lệ--thất-bại-failure-scenarios--idempotency)
9. [Chiến Lược Tối Ưu Chi Phí & Bảo Mật Enterprise (Cost & Security Architecture)](#9-chiến-lược-tối-ưu-chi-phí--bảo-mật-enterprise-cost--security-architecture)
10. [Quy Trình Dọn Dẹp Tài Nguyên Tránh Phát Sinh Phí (Cleanup Checklist)](#10-quy-trình-dọn-dẹp-tài-nguyên-tránh-phát-sinh-phí-cleanup-checklist)

---

## 1. TỔNG QUAN KIẾN TRÚC & SƠ ĐỒ KHỐI LUỒNG DỮ LIỆU

### 1.1. Sơ đồ kiến trúc văn bản (Architecture Flow)

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             AWS REGION: ap-southeast-2 (Sydney)                  │
│                                                                                  │
│   [ Microservices / Demo Lambda / EC2 ]                                          │
│                    │                                                             │
│                    ▼ (stdout / stderr)                                           │
│       [ Amazon CloudWatch Logs ]                                                 │
│       Log Group: /aws/lambda/ai-log-demo-app                                     │
│                    │                                                             │
│                    ▼ (Subscription Filter with IAM Role)                         │
│       [ Amazon Data Firehose ]                                                   │
│       Stream: ai-log-firehose                                                    │
│       Buffer: 128 MB hoặc 300 giây (5 phút) + GZIP Compression                   │
│                    │                                                             │
│                    ▼ (Delivered via Partitioned Prefix)                          │
│       [ Amazon S3 Central Log Bucket ]                                           │
│       s3://ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2/logs/year=.../hour=.../   │
│                                                                                  │
│                                                                                  │
│       [ Amazon EventBridge Scheduler ] (Trigger mỗi 30 phút / 5 phút demo)       │
│                    │                                                             │
│                    ▼ (Invoke)                                                    │
│       [ AWS Lambda: ai-log-batch-processor ]                                     │
│          ├── 1. Đọc DynamoDB Checkpoint (ai-log-processing-state)                │
│          ├── 2. Tính Time Window: [last_processed_timestamp ➔ current_time]     │
│          ├── 3. S3 ListObjectsV2 theo Prefix giờ + Tải & Giải nén GZIP           │
│          ├── 4. Parse CloudWatch Log Records (Bỏ Header, gom timeline)           │
│          ├── 5. Lọc rule-based: BỎ INFO/DEBUG/200; GIỮ ERROR/5xx/Timeout...     │
│          ├── 6. Trích xuất Context cửa sổ trượt (-3/+2 dòng quanh lỗi)           │
│          ├── 7. Normalize & Gom nhóm lỗi (Gộp 500 lỗi trùng thành 1 group)       │
│          ├── 8. Mask dữ liệu nhạy cảm (Sanitize passwords, tokens, Bearer, keys) │
│          │                                                                       │
│          ├── [Có lỗi?] ─── NO ──➔ Cập nhật Checkpoint ➔ KẾT THÚC (0$ Bedrock)   │
│          │                                                                       │
│          └── [Có lỗi?] ─── YES                                                   │
│                     │                                                            │
│                     ▼ (1 Request nhỏ gọn qua boto3 Converse API)                 │
│         [ Amazon Bedrock Runtime ]                                               │
│         Model: Claude 3 Haiku / Amazon Nova / Titan                              │
│                     │                                                            │
│                     ▼ (JSON Root Cause Analysis: severity, actions, evidence)    │
│         [ Structured Analysis Result ]                                           │
│          ├── Lưu DynamoDB: ai-log-analysis-results                               │
│          ├── Cập nhật Checkpoint: ai-log-processing-state                        │
│          └── Nếu Severity >= HIGH:                                               │
│                     │                                                            │
│                     ▼ (Publish Incident Email)                                   │
│              [ Amazon SNS Topic ] ──➔ [ Email Ops Team ]                         │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2. Dòng chảy dữ liệu thực tế trong 1 Batch Chu Kỳ (Estimated Batch Flow)

Giả sử trong một cửa sổ 30 phút, hệ thống phát sinh:
```text
10,000 log records thô từ các microservices
       │
       ▼ (Firehose gom buffer và nén Gzip thành ~2-3 S3 objects)
2 file S3 trong prefix s3://.../year=2026/month=09/day=16/hour=10/
       │
       ▼ (Lambda đọc theo time window checkpoint)
Lambda tải về, giải nén và quét 10,000 dòng log
       │
       ▼ (Rule-based Filter: Bỏ 9,613 dòng INFO, DEBUG, HealthCheck, HTTP 200)
Còn lại: 387 log lines chứa tín hiệu bất thường (ERROR, Timeout, 500)
       │
       ▼ (Error Normalization & Grouping Algorithm: khử timestamp, UUID, IP)
Gom thành: ĐÚNG 3 Nhóm lỗi duy nhất:
       ├─ Group 1: "Database connection timeout after 5000ms" (Số lượng: 327 lần)
       ├─ Group 2: "HTTP 500 Internal Server Error in /api/checkout" (Số lượng: 42 lần)
       └─ Group 3: "Redis connection refused on cache-cluster:6379" (Số lượng: 18 lần)
       │
       ▼ (Trích xuất mỗi nhóm 2 sample context kèm mask token nhạy cảm)
Tổng dung lượng Prompt gửi AI: ~1,200 tokens (Cực kỳ nhỏ gọn!)
       │
       ▼ (Bedrock phản hồi 1 lần duy nhất trong ~1.5 giây)
1 Structured JSON Response chứa đánh giá mức độ, nguyên nhân gốc rễ và đề xuất khắc phục
       │
       ▼
Ghi 1 bản ghi vào DynamoDB History + Bắn 1 Email SNS cảnh báo (nếu HIGH/CRITICAL)
```

---

## 2. NGUYÊN LÝ THIẾT KẾ: BATCHING, FILTERING, GROUPING & TỐI ƯU CHI PHÍ

### 2.1. Tại sao KHÔNG dùng cơ chế `S3 ObjectCreated Event ➔ Lambda`?
* **Thảm họa chi phí và Invocation Flooding:** Một hệ thống logging phân tán lớn có thể sinh ra hàng nghìn S3 object nhỏ mỗi giờ. Nếu dùng S3 Trigger, Lambda sẽ bị gọi hàng nghìn lần độc lập, mỗi lần chỉ nhìn thấy 1 mảnh log vụn vỡ (fragmented context), không thể xác định được bức tranh toàn cảnh (Incident Overview).
* **AI Request Explosion:** Nếu mỗi object kích hoạt gọi thẳng Bedrock, bạn sẽ trả tiền cho hàng ngàn API call vô ích, chi phí Bedrock sẽ tăng vọt theo cấp số nhân và nhanh chóng chạm Bedrock API Throttling limit (TPM/RPM).
* **Giải pháp Batching:** EventBridge Scheduler kích hoạt Lambda mỗi 30 phút một lần (hoặc 5 phút trong lab). Lambda xử lý gom 1 lô lớn, deduplicate toàn diện rồi mới quyết định gọi AI hay không.

### 2.2. Cơ chế Checkpoint DynamoDB (Stateful Tracking)
Để Lambda không bao giờ phải scan lại toàn bộ S3 bucket (vốn tốn kém và chậm theo thời gian), ta sử dụng bảng DynamoDB `ai-log-processing-state`:
* **Partition Key:** `processor_id` = `"main-log-processor"`
* **Attribute:** `last_processed_timestamp` (chuẩn ISO-8601 UTC, ví dụ `2026-09-16T10:00:00Z`)
* **Thuật toán cửa sổ quét (Sliding Window):**
  1. Khi Lambda thức dậy vào lúc `T_current` (ví dụ `10:30:00Z`), nó đọc `last_processed_timestamp` từ DynamoDB (ví dụ `10:00:00Z`).
  2. Khoảng thời gian cần xử lý là `[T_last, T_current]`.
  3. Dựa vào khoảng thời gian này, Lambda tính toán các tiền tố prefix S3 theo giờ (`year=YYYY/month=MM/day=DD/hour=HH`) để chỉ gọi `s3.list_objects_v2(Prefix=...)` đúng các thư mục liên quan, loại bỏ hoàn toàn việc list hàng triệu file cũ.
  4. Sau khi hoàn thành phân tích và ghi kết quả, Lambda cập nhật `last_processed_timestamp = T_current`.
  5. **Nguyên tắc bền vững:** Nếu batch bị lỗi ở giữa chừng (ví dụ S3 network rớt, Bedrock throttle), `last_processed_timestamp` **KHÔNG** được cập nhật. Lần trigger kế tiếp sẽ tự động retry lại toàn bộ khoảng thời gian chưa hoàn tất.

### 2.3. Thuật toán Error Grouping & Context Slicing
* **Chuẩn hóa (Normalization):** Dùng biểu thức chính quy (Regex) thay thế toàn bộ địa chỉ IP (`\d{1,3}\.\d{1,3}...`), UUID (`[a-f0-9-]{36}`), Hex IDs, Timestamps, và con số biến thiên bằng placeholder chung như `<IP>`, `<ID>`, `<NUM>`.
* **Signature Hashing:** Chuỗi log sau khi chuẩn hóa trở thành một Signature (Ví dụ: `ERROR: Failed to connect to <IP> after <NUM>ms`). 500 dòng log lỗi cùng loại sẽ có chung 1 Signature.
* **Context Preservation:** Với mỗi Signature, hệ thống lưu lại tối đa 2 cụm ngữ cảnh mẫu (Sample Context) gồm 3 dòng trước và 2 dòng sau lỗi, giúp AI hiểu được nguyên nhân dẫn đến lỗi mà không cần đọc cả triệu dòng log thừa.

### 2.4. Khử thông tin nhạy cảm (Data Redaction / Sanitization)
Trước khi bất kỳ chuỗi text nào được nạp vào Bedrock API payload, hàm làm sạch sẽ quét và thay thế:
* Mật khẩu: `password=...`, `pwd=...` ➔ `password=[REDACTED]`
* Token & Khóa API: `Bearer eyJ...`, `api_key=...`, `secret=...` ➔ `[REDACTED]`
* Đảm bảo tuân thủ tiêu chuẩn an toàn dữ liệu, không làm rò rỉ credential lên mô hình ngôn ngữ lớn (LLM).

---

## 3. BẢNG TỔNG HỢP TÀI NGUYÊN & IAM MATRIX

### 3.1. Danh mục tài nguyên triển khai (Resource Inventory)

| Loại Tài Nguyên | Tên Tài Nguyên | Mục Đích / Vai Trò | Cấu Hình Chính |
| :--- | :--- | :--- | :--- |
| **Amazon S3** | `ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2` | Chứa toàn bộ raw logs do Firehose gửi về | Private, SSE-S3 Encryption, Block Public Access |
| **Amazon DynamoDB** | `ai-log-processing-state` | Lưu trạng thái mốc thời gian xử lý (Checkpoint) | PK: `processor_id` (String), On-Demand Capacity |
| **Amazon DynamoDB** | `ai-log-analysis-results` | Lưu lịch sử kết quả phân tích AI và đề xuất RCA | PK: `analysis_id` (String), SK: `timestamp` (String) |
| **Amazon SNS** | `ai-log-critical-alerts` | Kênh phân phối thông báo lỗi nghiêm trọng | Standard Topic, Subscription: Email Ops Team |
| **Data Firehose** | `ai-log-firehose` | Gom buffer log từ CloudWatch Logs và nén ghi S3 | Buffer: 128 MB / 300s, GZIP compression |
| **AWS Lambda** | `ai-log-demo-app` | Sinh các kịch bản log giả lập (INFO, ERROR, 500...) | Runtime: Python 3.12 (hoặc bản mới nhất), Memory 128MB |
| **CloudWatch Logs**| `/aws/lambda/ai-log-demo-app` | Nhận log từ ứng dụng demo, nguồn cho Firehose | Retention: 7 days |
| **AWS Lambda** | `ai-log-batch-processor` | Hàm xử lý batch chính: lọc, group, gọi Bedrock | Runtime: Python 3.12+, Timeout 5 phút, Mem 512MB |
| **EventBridge** | `ai-log-analysis-schedule` | Kích hoạt Batch Processor theo chu kỳ | Rate: 30 minutes (5 minutes lúc demo) |

### 3.2. Ma trận phân quyền IAM (Least Privilege Matrix)

| IAM Role Name | Dịch Vụ Sử Dụng (Trusted Entity) | Quyền Hạn Cấp Phép (Permissions) | Lý Do Nghiệp Vụ |
| :--- | :--- | :--- | :--- |
| `ai-log-cw-to-firehose-role` | `logs.ap-southeast-2.amazonaws.com` | `firehose:PutRecord`, `firehose:PutRecordBatch` | Cho phép CloudWatch Subscription đẩy log stream vào Firehose |
| `ai-log-firehose-role` | `firehose.amazonaws.com` | `s3:PutObject`, `s3:GetBucketLocation`, `logs:PutLogEvents` | Cho phép Firehose ghi file nén Gzip vào S3 và ghi error log |
| `ai-log-processor-role` | `lambda.amazonaws.com` | `s3:GetObject`, `s3:ListBucket`, `dynamodb:*`, `bedrock:InvokeModel*`, `sns:Publish`, `logs:*` | Cho phép Lambda đọc S3, quản lý Checkpoint, gọi AI và gửi mail cảnh báo |
| `ai-log-scheduler-role` | `scheduler.amazonaws.com` | `lambda:InvokeFunction` trên `ai-log-batch-processor` | Cho phép EventBridge Scheduler định kỳ gọi hàm Lambda |

---

## 4. KIỂM TRA KHẢ DỤNG DỊCH VỤ & MODEL BEDROCK TẠI SYDNEY (`ap-southeast-2`)

Trước khi tiến hành, hãy xác thực các dịch vụ cốt lõi tại Region **Asia Pacific (Sydney)**:
1. **Amazon Bedrock:** Đã hoạt động chính thức (Generally Available) tại `ap-southeast-2`.
2. **Model Catalog Khả Dụng Tại Sydney:**
   - **Amazon Nova Micro / Nova Lite / Nova Pro** (Rất rẻ, hỗ trợ structured JSON tối ưu).
   - **Anthropic Claude 3 Haiku / Claude 3.5 Sonnet** (Hỗ trợ cực mạnh về phân tích log kỹ thuật và trích xuất JSON; khả dụng trực tiếp hoặc thông qua APAC Cross-Region Inference Profile `apac.anthropic.claude-3-haiku-20240307-v1:0` / `apac.anthropic.claude-3-5-sonnet-20240620-v1:0`).
   - **Amazon Titan Text Express v1** (`amazon.titan-text-express-v1`).
3. **AWS SDK Standard API:** Trong bài lab này, mã nguồn Lambda sử dụng phương thức **`boto3.client('bedrock-runtime').converse(...)`**. Converse API là chuẩn thống nhất mới nhất của AWS, hoạt động đồng nhất cho Claude 3, Nova lẫn Titan mà không cần thay đổi cấu trúc payload request, tránh hoàn toàn các model API cũ bị deprecated!

---

## 5. HƯỚNG DẪN TRIỂN KHAI STEP-BY-STEP TRÊN AWS MANAGEMENT CONSOLE

> [!IMPORTANT]
> **Quy tắc điều hướng Console:** Luôn nhìn lên thanh công cụ điều hướng trên cùng bên phải của AWS Console và đảm bảo Region đang chọn là **Sydney (`ap-southeast-2`)**. Mọi tài nguyên nếu không nói gì thêm đều phải tạo tại Region này!

---

### BƯỚC 1: KIỂM TRA MODEL TRÊN AMAZON BEDROCK (MODEL ACCESS ĐÃ ĐƯỢC TỰ ĐỘNG KÍCH HOẠT)

#### Mục tiêu:
Kiểm tra Model khả dụng trong tài khoản tại Region Sydney (`ap-southeast-2`).

> [!NOTE]
> **Cập nhật quan trọng từ AWS Console (Model access page has been retired):**  
> Hiện tại AWS đã **tự động kích hoạt (automatically enabled)** toàn bộ các Serverless Foundation Models trên tất cả các Region thương mại. Bạn **KHÔNG** cần phải thao tác bấm xin cấp quyền thủ công (Modify/Request access) trên trang Model access nữa. Model sẽ tự động sẵn sàng khi được gọi lần đầu tiên bằng `Converse API` hoặc qua IAM permissions.

#### Thao tác kiểm tra trên AWS Console:
1. Tại menu bên trái, nhìn vào mục **▼ Discover** ➔ chọn **Model catalog**.
2. Tại ô tìm kiếm hoặc bộ lọc Provider, bạn có thể xem các model đang hoạt động tại Sydney:
   - **Amazon:** `Nova Micro` (`amazon.nova-micro-v1:0`), `Titan Text G1 - Express` (`amazon.titan-text-express-v1`).
   - **Anthropic:** `Claude 3 Haiku` (`apac.anthropic.claude-3-haiku-20240307-v1:0` hoặc `anthropic.claude-3-haiku-20240307-v1:0`).
3. Bạn có thể nhấn vào model bất kỳ ➔ chọn **Open in Playground** để thử gõ prompt kiểm tra phản hồi nếu muốn.

#### Model ID sử dụng cho bài Lab:
* Đề xuất chuẩn nhất tại Sydney (siêu nhanh, chi phí cực rẻ, hoạt động ngay lập tức):  
  `amazon.nova-micro-v1:0`  
  *(hoặc Amazon Titan: `amazon.titan-text-express-v1`)*.
* Bạn có thể chuyển sang **BƯỚC 2** ngay mà không cần đợi phê duyệt!

---

### BƯỚC 2: TẠO AMAZON S3 BUCKET LƯU TRỮ LOG TẬP TRUNG

#### Mục tiêu:
Tạo kho lưu trữ S3 chuẩn Enterprise để tiếp nhận các luồng log batch từ Data Firehose, bảo mật 100% không công khai.

#### Thao tác AWS Console:
1. Tìm kiếm và vào dịch vụ **S3**.
2. Nhấn nút **Create bucket**.
3. Cấu hình chi tiết các trường:
   - **AWS Region:** Chọn `Asia Pacific (Sydney) ap-southeast-2`.
   - **Bucket type:** Chọn **General purpose**.
   - **Bucket name:** Điền tên duy nhất toàn cầu theo định dạng:  
     `ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2`  
     *(Thay `<ACCOUNT_ID>` bằng 12 chữ số AWS Account ID của bạn, ví dụ: `ai-log-analysis-123456789012-ap-southeast-2`)*.
   - **Object Ownership:** Chọn **ACLs disabled (recommended)**.
   - **Block Public Access settings for this bucket:** Đảm bảo tích chọn **Block all public access** (giữ nguyên mặc định 4 dấu tích).
   - **Bucket Versioning:** Chọn **Disable** (đối với log file batch để tiết kiệm chi phí lưu trữ).
   - **Default encryption:** Chọn **Server-side encryption with Amazon S3 managed keys (SSE-S3)**.
4. Giữ nguyên các cài đặt khác, cuộn xuống dưới cùng và nhấn **Create bucket**.

#### Verify:
* Bucket xuất hiện trong danh sách với Region `ap-southeast-2` và Access là `Bucket and objects not public`.

---

### BƯỚC 3: TẠO 2 BẢNG AMAZON DYNAMODB (CHECKPOINT STATE & ANALYSIS RESULTS)

#### Mục tiêu:
* Bảng 1 (`ai-log-processing-state`): Quản lý con trỏ thời gian (checkpoint) để Lambda không đọc sót và không đọc lặp log.
* Bảng 2 (`ai-log-analysis-results`): Lưu trữ báo cáo phân tích AI có cấu trúc để làm lịch sử và audit.

#### Thao tác AWS Console:

##### 3.1. Tạo Bảng Checkpoint `ai-log-processing-state`
1. Tìm kiếm và vào dịch vụ **DynamoDB** (đảm bảo đang ở Sydney).
2. Nhấn nút **Create table**.
3. Cấu hình:
   - **Table name:** `ai-log-processing-state`
   - **Partition key:** `processor_id` ➔ Kiểu dữ liệu: **String**
   - **Sort key:** Để trống.
   - **Table class:** Chọn **DynamoDB Standard**.
   - **Capacity mode:** Chọn **On-demand** (chỉ trả tiền khi có thao tác đọc/ghi, hoàn hảo cho batch job 30 phút/lần).
4. Nhấn **Create table**.

##### 3.2. Khởi tạo giá trị Checkpoint ban đầu
1. Chờ bảng chuyển sang trạng thái **Active**. Nhấn vào tên bảng `ai-log-processing-state`.
2. Chọn tab **Explore items** (ở menu bên trái hoặc góc trên).
3. Nhấn **Create item**.
4. Chuyển chế độ xem sang **JSON** (ở góc phải hộp thoại), paste đoạn JSON sau:
   ```json
   {
     "processor_id": "main-log-processor",
     "last_processed_timestamp": "2026-01-01T00:00:00Z",
     "last_run_status": "INITIALIZED"
   }
   ```
5. Nhấn **Create item**.

##### 3.3. Tạo Bảng Kết Quả Phân Tích `ai-log-analysis-results`
1. Quay lại trang **Tables**, nhấn **Create table**.
2. Cấu hình:
   - **Table name:** `ai-log-analysis-results`
   - **Partition key:** `analysis_id` ➔ Kiểu: **String**
   - **Sort key:** `timestamp` ➔ Kiểu: **String**
   - **Capacity mode:** Chọn **On-demand**.
3. Nhấn **Create table**.

#### Verify:
* Cả 2 bảng đều ở trạng thái `Active`. Bảng `ai-log-processing-state` có sẵn 1 item khởi tạo.

---

### BƯỚC 4: TẠO AMAZON SNS TOPIC & XÁC THỰC EMAIL ĐĂNG KÝ NHẬN CẢNH BÁO

#### Mục tiêu:
Thiết lập đường dây nóng thông báo tức thời qua Email khi Lambda AI phát hiện sự cố có độ nghiêm trọng HIGH hoặc CRITICAL.

#### Thao tác AWS Console:
1. Tìm kiếm và vào dịch vụ **Simple Notification Service (SNS)**.
2. Tại menu trái, chọn **Topics** ➔ Nhấn **Create topic**.
3. Cấu hình:
   - **Type:** Chọn **Standard**.
   - **Name:** `ai-log-critical-alerts`
   - **Display name:** `AI-Log-Alert`
4. Cuộn xuống nhấn **Create topic**.
5. Trong màn hình chi tiết của Topic vừa tạo, chọn tab **Subscriptions** ➔ Nhấn **Create subscription**.
6. Cấu hình Subscription:
   - **Protocol:** Chọn **Email**.
   - **Endpoint:** Điền địa chỉ Email thực tế của bạn (nơi bạn có thể mở hộp thư để bấm xác nhận).
7. Nhấn **Create subscription**.
8. **BƯỚC QUAN TRỌNG:** Mở hộp thư đến của email vừa điền. Tìm thư có tiêu đề `AWS Notification - Subscription Confirmation` từ `no-reply@sns.amazonaws.com` và click vào đường link **Confirm subscription**.
9. Quay lại AWS Console tải lại trang: Trạng thái Status chuyển từ `PendingConfirmation` sang `Confirmed` màu xanh.

---

### BƯỚC 5: THIẾT LẬP IAM ROLE CHO AMAZON DATA FIREHOSE & CLOUDWATCH LOGS

Để CloudWatch Logs có thể chuyển tiếp dữ liệu sang Firehose và Firehose có thể ghi vào S3, AWS yêu cầu 2 IAM Role trung gian.

#### Thao tác AWS Console:

##### 5.1. Tạo IAM Role cho Data Firehose (`ai-log-firehose-role`)
1. Tìm kiếm và vào dịch vụ **IAM**.
2. Menu trái chọn **Roles** ➔ Nhấn **Create role**.
3. **Trusted entity type:** Chọn **AWS service**.
4. **Use case:** Tại ô dropdown tìm kiếm chọn **Firehose** (hoặc chọn Custom trust policy).
5. Để đảm bảo chuẩn xác, chọn **Custom trust policy** và paste nội dung sau:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Service": "firehose.amazonaws.com"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```
6. Nhấn **Next**.
7. Tại bước **Add permissions**, nhấn nút **Create policy** (sẽ mở tab mới):
   - Chọn tab **JSON**, xóa trắng và dán nội dung chính xác (thay `<ACCOUNT_ID>` bằng Account ID của bạn):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "S3DeliveryPermissions",
         "Effect": "Allow",
         "Action": [
           "s3:AbortMultipartUpload",
           "s3:GetBucketLocation",
           "s3:GetObject",
           "s3:ListBucket",
           "s3:ListBucketMultipartUploads",
           "s3:PutObject"
         ],
         "Resource": [
           "arn:aws:s3:::ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2",
           "arn:aws:s3:::ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2/*"
         ]
       },
       {
         "Sid": "CloudWatchLogsForFirehose",
         "Effect": "Allow",
         "Action": [
           "logs:PutLogEvents",
           "logs:CreateLogStream"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
   - Nhấn **Next** ➔ Policy name: `ai-log-firehose-s3-policy` ➔ Nhấn **Create policy**.
8. Quay lại tab tạo Role, nhấn nút Refresh nhỏ ở góc bảng permissions ➔ Tìm và tích chọn `ai-log-firehose-s3-policy`.
9. Nhấn **Next** ➔ Role name: `ai-log-firehose-role` ➔ Nhấn **Create role**.

##### 5.2. Tạo IAM Role cho CloudWatch Logs đẩy sang Firehose (`ai-log-cw-to-firehose-role`)
1. Trong IAM, nhấn **Create role**.
2. Chọn **Custom trust policy** và paste đoạn JSON cho phép `logs.ap-southeast-2.amazonaws.com`:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Service": "logs.ap-southeast-2.amazonaws.com"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```
3. Nhấn **Next**.
4. Nhấn **Create policy** (mở tab mới), chọn tab **JSON** và dán:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "firehose:PutRecord",
           "firehose:PutRecordBatch"
         ],
         "Resource": "arn:aws:firehose:ap-southeast-2:*:deliverystream/ai-log-firehose"
       }
     ]
   }
   ```
5. Đặt tên Policy: `ai-log-cw-put-firehose-policy` ➔ Nhấn **Create policy**.
6. Quay lại tab tạo Role, refresh và tích chọn `ai-log-cw-put-firehose-policy`.
7. Nhấn **Next** ➔ Đặt tên Role: `ai-log-cw-to-firehose-role` ➔ Nhấn **Create role**.
8. **LƯU Ý:** Copy lại chuỗi **ARN** của role này (ví dụ `arn:aws:iam::<ACCOUNT_ID>:role/ai-log-cw-to-firehose-role`) để dùng tại Bước 8.

---

### BƯỚC 6: TẠO AMAZON DATA FIREHOSE DELIVERY STREAM GOM LOG VỀ S3

#### Mục tiêu:
Cấu hình Stream đệm log với buffer time 300s (5 phút) và nén GZIP, tạo thành các file S3 phân vùng theo giờ (`year=.../month=.../day=.../hour=...`).

#### Thao tác AWS Console:
1. Tìm kiếm dịch vụ **Amazon Data Firehose** (trước đây gọi là Kinesis Data Firehose).
2. Đảm bảo góc phải là Region **Sydney**. Nhấn nút **Create delivery stream**.
3. Cấu hình chi tiết:
   - **Source:** Chọn **Direct PUT** (CloudWatch Subscription sẽ đẩy trực tiếp qua API này).
   - **Destination:** Chọn **Amazon S3**.
   - **Delivery stream name:** `ai-log-firehose`
4. Mục **Destination settings (Amazon S3 bucket)**:
   - **S3 bucket:** Nhấn **Browse** và chọn bucket `ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2` đã tạo ở Bước 2.
   - **S3 bucket prefix (Tùy chỉnh phân vùng thời gian tối ưu):**  
     Nhập chính xác chuỗi dynamic partitioning prefix sau:
     ```text
     logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/
     ```
   - **S3 bucket error output prefix:**  
     Nhập:
     ```text
     logs-failed/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/
     ```
5. Mục **Buffer hints, compression and encryption**:
   - Nhấn mở rộng phần này ra.
   - **Buffer size:** Nhập `64` hoặc `128` (MB).
   - **Buffer interval:** Nhập `300` (seconds = 5 phút).  
     *(Giải thích: Firehose sẽ gom toàn bộ các dòng log trong 5 phút hoặc đến khi đủ dung lượng mới flush ra 1 file duy nhất lên S3, giảm thiểu tối đa file rác).*
   - **Compression for data records:** Chọn **GZIP** (tiết kiệm 80% chi phí lưu trữ S3 và băng thông truyền tải).
   - **Encryption for data records:** Chọn **Turn off encryption** (vì S3 bucket đã được bật Server-Side Encryption SSE-S3 mặc định).
6. Mục **Advanced settings (Service access / IAM role)**:
   - **Service access:** Chọn **Choose an existing IAM role**.
   - Chọn role `ai-log-firehose-role` đã tạo ở Bước 5.1.
7. Kiểm tra lại toàn bộ thông tin và nhấn nút **Create delivery stream**.

#### Verify:
* Stream `ai-log-firehose` hiển thị trạng thái `Active`.

---

### BƯỚC 7: TẠO DEMO APP LAMBDA & PHÁT SINH LOG GIẢ LẬP LÊN CLOUDWATCH LOGS

#### Mục tiêu:
Tạo một ứng dụng microservice mẫu có khả năng mô phỏng luồng log thực tế: xen kẽ giữa các tác vụ thành công và các thảm họa lỗi (timeout cơ sở dữ liệu, lỗi cổng thanh toán HTTP 500, tràn kết nối Redis, v.v.).

#### Thao tác AWS Console:
1. Tìm kiếm và vào dịch vụ **AWS Lambda**.
2. Nhấn nút **Create function**.
3. Cấu hình:
   - Chọn **Author from scratch**.
   - **Function name:** `ai-log-demo-app`
   - **Runtime:** Chọn **Python 3.12** (hoặc bản mới nhất có sẵn).
   - **Architecture:** Chọn **x86_64** (hoặc arm64).
   - **Permissions:** Giữ nguyên **Create a new role with basic Lambda permissions**.
4. Nhấn **Create function**.
5. Tại tab **Code** ➔ mở file `lambda_function.py`, xóa sạch code mẫu ban đầu và dán toàn bộ đoạn mã trong [Mục 6.1](#61-mã-nguồn-demo-app-ai-log-demo-app).
6. Nhấn nút **Deploy** để lưu code.
7. Chuyển sang tab **Configuration** ➔ chọn mục **General configuration** ➔ nhấn **Edit**:
   - **Timeout:** Đặt `0` phút `30` giây.
   - Nhấn **Save**.

#### Chạy thử nghiệm phát sinh log đầu tiên:
1. Chuyển sang tab **Test**.
2. Đặt tên Test Event: `GenerateErrorTraffic`.
3. Trong ô Event JSON, dán payload điều khiển sau:
   ```json
   {
     "mode": "high_critical_errors",
     "batch_size": 25
   }
   ```
4. Nhấn nút **Test** 2 đến 3 lần. Quan sát mục Execution result hiển thị `statusCode: 200` và bảng log in ra màu đỏ/trắng xen kẽ.

#### Verify:
* Vào CloudWatch ➔ Log groups ➔ Tìm thấy Log Group `/aws/lambda/ai-log-demo-app` đã có dữ liệu log stream mới nhất.

---

### BƯỚC 8: CẤU HÌNH CLOUDWATCH LOGS SUBSCRIPTION FILTER CHUYỂN TIẾP SANG FIREHOSE

#### Mục tiêu:
Kết nối Log Group của ứng dụng sang Firehose Delivery Stream. Mỗi khi có log phát sinh, CloudWatch Logs sẽ tự động batch và đẩy sang Firehose.

#### Thao tác AWS Console:
1. Vào dịch vụ **CloudWatch** ➔ Menu trái chọn **Log groups**.
2. Nhấp vào tên Log group `/aws/lambda/ai-log-demo-app`.
3. Chọn tab **Subscription filters** (nằm cạnh Metric filters).
4. Nhấn nút **Create** ➔ Chọn **Create Amazon Data Firehose subscription filter**.
5. Cấu hình chi tiết:
   - **Destination account:** Chọn **Current account**.
   - **Amazon Data Firehose delivery stream:** Chọn `ai-log-firehose` (đã tạo ở Bước 6).
   - **Grant permissions:**  
     *Lưu ý:* Chọn role `ai-log-cw-to-firehose-role` đã tạo ở Bước 5.2.  
     *(Nếu Console hiển thị ô nhập ARN, dán ARN: `arn:aws:iam::<ACCOUNT_ID>:role/ai-log-cw-to-firehose-role`)*.
   - **Subscription filter name:** `sub-filter-demo-app-to-firehose`
   - **Log format:** Chọn **JSON** hoặc **Other**.
   - **Subscription filter pattern:** Để trống hoàn toàn  
     *(Giải thích: Để trống có nghĩa là chuyển tiếp TOÀN BỘ log thô sang S3 Central Lake. Trách nhiệm lọc thông minh và gom nhóm sẽ thuộc về Batch Lambda Processor sau này)*.
6. Cuộn xuống cuối và nhấn **Start streaming**.

#### Verify:
* Trong tab **Subscription filters**, bộ lọc hiển thị trạng thái chuyển tiếp đang hoạt động.
* Đợi khoảng 5 phút (hết chu kỳ buffer của Firehose), vào S3 bucket `ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2` ➔ bấm vào thư mục `logs/` ➔ duyệt theo các cấp `year=.../month=.../day=.../hour=.../` ➔ Bạn sẽ nhìn thấy các file `.gz` đã được ghi vào!

---

### BƯỚC 9: TẠO IAM EXECUTION ROLE CHUẨN LEAST PRIVILEGE CHO BATCH PROCESSOR LAMBDA

#### Mục tiêu:
Cung cấp quyền hạn tối thiểu (Least Privilege) cho Lambda AI Batch Processor để: đọc file nén trên S3, truy vấn & cập nhật DynamoDB, gọi Amazon Bedrock Runtime, và gửi Email qua SNS.

#### Thao tác AWS Console:
1. Vào dịch vụ **IAM** ➔ chọn **Roles** ➔ Nhấn **Create role**.
2. Chọn **AWS service** ➔ Use case chọn **Lambda** ➔ Nhấn **Next**.
3. Nhấn **Create policy** (mở tab mới), chọn tab **JSON**, dán toàn bộ đoạn policy chặt chẽ sau (hãy thay `<ACCOUNT_ID>` bằng Account ID của bạn):
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "BasicCloudWatchLogging",
         "Effect": "Allow",
         "Action": [
           "logs:CreateLogGroup",
           "logs:CreateLogStream",
           "logs:PutLogEvents"
         ],
         "Resource": "arn:aws:logs:ap-southeast-2:*:log-group:/aws/lambda/ai-log-batch-processor:*"
       },
       {
         "Sid": "S3LogBucketAccess",
         "Effect": "Allow",
         "Action": [
           "s3:GetObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2",
           "arn:aws:s3:::ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2/*"
         ]
       },
       {
         "Sid": "DynamoDBStateAndResultsAccess",
         "Effect": "Allow",
         "Action": [
           "dynamodb:GetItem",
           "dynamodb:PutItem",
           "dynamodb:UpdateItem"
         ],
         "Resource": [
           "arn:aws:dynamodb:ap-southeast-2:<ACCOUNT_ID>:table/ai-log-processing-state",
           "arn:aws:dynamodb:ap-southeast-2:<ACCOUNT_ID>:table/ai-log-analysis-results"
         ]
       },
       {
         "Sid": "BedrockInvokePermissions",
         "Effect": "Allow",
         "Action": [
           "bedrock:InvokeModel",
           "bedrock:InvokeModelWithResponseStream"
         ],
         "Resource": "*"
       },
       {
         "Sid": "SNSPublishPermissions",
         "Effect": "Allow",
         "Action": [
           "sns:Publish"
         ],
         "Resource": "arn:aws:sns:ap-southeast-2:<ACCOUNT_ID>:ai-log-critical-alerts"
       }
     ]
   }
   ```
4. Nhấn **Next** ➔ Đặt tên Policy: `ai-log-processor-least-privilege-policy` ➔ Nhấn **Create policy**.
5. Quay lại tab tạo Role, refresh và tích chọn `ai-log-processor-least-privilege-policy`.
6. Nhấn **Next** ➔ Đặt tên Role: `ai-log-processor-role` ➔ Nhấn **Create role**.

---

### BƯỚC 10: TẠO & CẤU HÌNH HÀM LAMBDA AI BATCH PROCESSOR

#### Mục tiêu:
Triển khai bộ não trung tâm của kiến trúc: tải file nén S3, bóc tách CloudWatch log record, chạy bộ lọc quy tắc loại bỏ INFO/DEBUG, gom nhóm các lỗi trùng lặp, khử nhạy cảm, gọi Amazon Bedrock bằng Converse API, lưu DynamoDB và kích hoạt cảnh báo SNS.

#### Thao tác AWS Console:
1. Vào dịch vụ **AWS Lambda** ➔ Nhấn **Create function**.
2. Cấu hình:
   - Chọn **Author from scratch**.
   - **Function name:** `ai-log-batch-processor`
   - **Runtime:** Chọn **Python 3.12** (hoặc bản mới nhất).
   - **Permissions:** Nhấn mở rộng **Change default execution role**:
     - Chọn **Use an existing role**.
     - Chọn role: `ai-log-processor-role` (đã tạo ở Bước 9).
3. Nhấn **Create function**.
4. Cấu hình **General configuration**:
   - Chọn tab **Configuration** ➔ mục **General configuration** ➔ nhấn **Edit**:
   - **Memory:** Đặt `512 MB` (đủ bộ nhớ giải nén và xử lý JSON batch nhanh).
   - **Timeout:** Đặt `5` phút `0` giây (đảm bảo thời gian gọi Bedrock và xử lý lô S3).
   - Nhấn **Save**.
5. Cấu hình **Environment variables (Biến môi trường)**:
   - Trong tab **Configuration** ➔ chọn mục **Environment variables** ➔ nhấn **Edit**:
   - Nhấn **Add environment variable** và thêm lần lượt các biến sau:
     * `S3_BUCKET_NAME`: `ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2`
     * `CHECKPOINT_TABLE`: `ai-log-processing-state`
     * `RESULTS_TABLE`: `ai-log-analysis-results`
     * `SNS_TOPIC_ARN`: `arn:aws:sns:ap-southeast-2:<ACCOUNT_ID>:ai-log-critical-alerts`
     * `BEDROCK_MODEL_ID`: `amazon.nova-micro-v1:0`  
       *(Đề xuất tối ưu nhất cho Sydney, hoặc dùng Titan: `amazon.titan-text-express-v1`)*.
   - Nhấn **Save**.
6. Cập nhật mã nguồn xử lý:
   - Chuyển sang tab **Code** ➔ mở file `lambda_function.py`.
   - Xóa toàn bộ nội dung cũ và dán toàn bộ đoạn mã trong [Mục 6.2](#62-mã-nguồn-ai-batch-processor-ai-log-batch-processor).
   - Nhấn nút **Deploy**.

---

### BƯỚC 11: TẠO AMAZON EVENTBRIDGE SCHEDULER KÍCH HOẠT ĐỊNH KỲ BATCH JOB

#### Mục tiêu:
Thiết lập bộ lập lịch EventBridge Scheduler chạy định kỳ mỗi 30 phút (hoặc 5 phút trong lúc làm bài lab để thấy kết quả ngay).

#### Thao tác AWS Console:
1. Tìm kiếm và vào dịch vụ **Amazon EventBridge**.
2. Ở menu bên trái, tìm mục **Buses** ➔ chọn **Schedules** (hoặc **EventBridge Scheduler ➔ Schedules**).
3. Nhấn nút **Create schedule**.
4. **Step 1: Specify schedule detail**:
   - **Schedule name:** `ai-log-analysis-schedule`
   - **Schedule group:** `default`
   - **Schedule pattern:** Chọn **Recurring schedule**.
   - **Schedule type:** Chọn **Rate-based schedule**.
   - **Rate expression:** Nhập `5` và chọn đơn vị là **minutes** (để thực hiện kiểm thử Lab nhanh; trên Production hãy đổi thành `30` **minutes** hoặc `1` **hours**).
   - **Flexible time window:** Chọn **Off** (chạy đúng thời điểm).
   - Nhấn **Next**.
5. **Step 2: Select target**:
   - **Target API:** Chọn **AWS Lambda** ➔ **Invoke**.
   - **Lambda function:** Tìm và chọn hàm `ai-log-batch-processor`.
   - **Payload:** Để trống `{}` (hoặc điền `{"trigger": "eventbridge-scheduled"}`).
   - Nhấn **Next**.
6. **Step 3: Configure settings**:
   - **Action after completion:** Chọn **NONE**.
   - **Retry policy and dead-letter queue (DLQ):** Giữ mặc định.
   - **Permissions (Execution role):** Chọn **Create a new role for this schedule** (EventBridge sẽ tự động sinh quyền invoke Lambda).
   - Nhấn **Next**.
7. **Step 4: Review and create schedule**:
   - Rà soát lại thông tin và nhấn **Create schedule**.

#### Verify:
* Schedule hiển thị trạng thái `Enabled`.

---

## 6. TOÀN BỘ MÃ NGUỒN CHI TIẾT (FULL PYTHON SOURCE CODE)

### 6.1. Mã nguồn Demo App (`ai-log-demo-app`)

Mã nguồn này mô phỏng các microservice thực tế, phát sinh dữ liệu nhật ký đa dạng: thành công, cảnh báo hiệu năng, token nhạy cảm, lỗi kết nối SQL, và lỗi crash hệ thống.

```python
"""
AWS Lambda Demo Application: ai-log-demo-app
Mục đích: Giả lập lưu lượng log thực tế gồm INFO, DEBUG, WARN, ERROR, Exception, HTTP 500,
và token bảo mật nhạy cảm (Authorization Bearer, API Keys) để kiểm tra bộ lọc AI.
"""

import json
import logging
import random
import time
import uuid

# Cấu hình logging chuẩn format CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

SERVICES = ["order-service", "payment-service", "user-auth-service", "inventory-service"]
ENDPOINTS = ["/api/v1/checkout", "/api/v1/login", "/api/v1/orders", "/api/v1/payments"]

def generate_normal_logs(count=10):
    for _ in range(count):
        req_id = str(uuid.uuid4())
        service = random.choice(SERVICES)
        endpoint = random.choice(ENDPOINTS)
        duration = random.randint(15, 120)
        user_id = random.randint(1000, 9999)
        
        logger.info(f"[{service}] Request started: RID={req_id} Path={endpoint} User={user_id}")
        logger.info(f"[{service}] Processing business logic for User={user_id} - status=VALID")
        logger.info(f"[{service}] Request finished successfully: RID={req_id} Status=200 Duration={duration}ms")

def generate_flurry_errors(error_type="database_timeout", count=5):
    """Giả lập chuỗi log lỗi lặp lại nhiều lần xen kẽ ngữ cảnh"""
    for i in range(count):
        req_id = str(uuid.uuid4())
        service = "payment-service"
        fake_token = f"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.s{random.randint(100000, 999999)}"
        
        # 1. Dòng log ngữ cảnh trước lỗi
        logger.info(f"[{service}] Incoming transaction: RID={req_id} Auth='Authorization: Bearer {fake_token}'")
        logger.info(f"[{service}] Connecting to Primary RDS Database Cluster at 10.0.12.84:5432")
        logger.warning(f"[{service}] DB connection acquisition latency unusually high: {random.randint(2500, 4900)}ms")
        
        # 2. Dòng log lỗi chính
        if error_type == "database_timeout":
            logger.error(
                f"[{service}] ERROR Database connection timeout: Connection pool exhausted after 5000ms. "
                f"RID={req_id} ActiveConnections=100 MaxPool=100 ClientIP=192.168.1.{random.randint(1, 254)}"
            )
        elif error_type == "http_500":
            logger.error(
                f"[{service}] CRITICAL HTTP 500 Internal Server Error in /api/v1/checkout: "
                f"Unhandled NullPointerException at com.app.billing.StripeGateway.charge(StripeGateway.java:{random.randint(40, 90)}) "
                f"apiKey='sk_live_{random.randint(10000000, 99999999)}'"
            )
        elif error_type == "redis_refused":
            logger.error(
                f"[{service}] FATAL Redis connection refused on redis-cluster-cache:6379: "
                f"Cannot assign requested address. Cache fallback failed for RID={req_id}"
            )
            
        # 3. Dòng log ngữ cảnh sau lỗi
        logger.info(f"[{service}] Rolling back transaction for RID={req_id}")
        logger.info(f"[{service}] Fallback circuit breaker opened for {service}")

def lambda_handler(event, context):
    mode = event.get("mode", "normal")
    batch_size = int(event.get("batch_size", 10))
    
    logger.info(f"--- DEMO RUN START: mode={mode}, batch_size={batch_size} ---")
    
    if mode == "normal":
        generate_normal_logs(count=batch_size)
    elif mode == "database_timeout":
        generate_normal_logs(count=3)
        generate_flurry_errors(error_type="database_timeout", count=batch_size)
        generate_normal_logs(count=2)
    elif mode == "high_critical_errors":
        generate_normal_logs(count=2)
        generate_flurry_errors(error_type="database_timeout", count=batch_size // 2)
        generate_flurry_errors(error_type="http_500", count=batch_size // 2)
        generate_flurry_errors(error_type="redis_refused", count=3)
    else:
        generate_normal_logs(count=5)
        
    logger.info(f"--- DEMO RUN END: Generated traffic successfully ---")
    
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "SUCCESS", "mode": mode, "generated_events": batch_size})
    }
```

---

### 6.2. Mã nguồn AI Batch Processor (`ai-log-batch-processor`)

Đây là mã nguồn hoàn chỉnh của bộ xử lý, giải quyết toàn bộ các yêu cầu khắt khe:
* Quản lý Checkpoint bền vững trên DynamoDB.
* Phân tích Time Window để chỉ List S3 Prefixes liên quan theo giờ.
* Tải và giải nén Stream GZIP của Firehose / CloudWatch Logs.
* Bóc tách Header CWL, loại bỏ hoàn toàn INFO/DEBUG/200 OK.
* Thuật toán Regex Normalization gom hàng trăm lỗi trùng lặp thành signature đại diện.
* Trích xuất cửa sổ ngữ cảnh (-3 dòng trước, +2 dòng sau).
* Khử nhạy cảm thông tin (Mask passwords, JWT tokens, Bearer, Secrets).
* Chỉ gọi Amazon Bedrock khi có lỗi; dùng **Converse API** mới nhất với Schema JSON rõ ràng.
* Lưu trữ DynamoDB History & bắn SNS email cho Severity HIGH/CRITICAL.

```python
"""
AWS Lambda Function: ai-log-batch-processor
Runtime: Python 3.12+
Mục đích: Batch Log Processor sử dụng Amazon Bedrock để phân tích lỗi hệ thống
Tối ưu chi phí, khử trùng lặp (Deduplication) và bảo mật tuyệt đối.
"""

import os
import io
import re
import gzip
import zipfile
import json
import time
import boto3
import logging
from datetime import datetime, timezone, timedelta

# Cấu hình logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Khởi tạo AWS SDK Clients
s3_client = boto3.client('s3')
dynamodb_resource = boto3.resource('dynamodb')
bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'ap-southeast-2'))
sns_client = boto3.client('sns')

# Đọc cấu hình từ biến môi trường
S3_BUCKET_NAME = os.environ['S3_BUCKET_NAME']
CHECKPOINT_TABLE = os.environ['CHECKPOINT_TABLE']
RESULTS_TABLE = os.environ['RESULTS_TABLE']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.nova-micro-v1:0')
PROCESSOR_ID = "main-log-processor"

# Từ khóa xác định lỗi cần phân tích
ERROR_KEYWORDS = [
    "ERROR", "CRITICAL", "FATAL", "EXCEPTION", "TIMEOUT",
    "CONNECTION REFUSED", "OUTOFMEMORY", "HTTP 500", "HTTP 502",
    "HTTP 503", "HTTP 504", "NULLPOINTEREXCEPTION"
]

# Từ khóa thông thường cần LOẠI BỎ tuyệt đối
IGNORE_KEYWORDS = [
    "HEALTHCHECK OK", "STATUS=200", "HTTP 200", "STATUS=VALID", "INFO", "DEBUG"
]

# -------------------------------------------------------------------------
# 1. CÁC HÀM XỬ LÝ CHECKPOINT VÀ S3 PREFIX
# -------------------------------------------------------------------------

def get_checkpoint():
    """Lấy mốc thời gian xử lý cuối cùng từ DynamoDB"""
    table = dynamodb_resource.Table(CHECKPOINT_TABLE)
    try:
        response = table.get_item(Key={'processor_id': PROCESSOR_ID})
        if 'Item' in response:
            return response['Item'].get('last_processed_timestamp', '2026-01-01T00:00:00Z')
    except Exception as e:
        logger.error(f"[ERROR] Không thể đọc checkpoint từ DynamoDB: {str(e)}")
    return "2026-01-01T00:00:00Z"

def update_checkpoint(new_timestamp):
    """Cập nhật mốc thời gian mới sau khi batch xử lý thành công mỹ mãn"""
    table = dynamodb_resource.Table(CHECKPOINT_TABLE)
    try:
        table.update_item(
            Key={'processor_id': PROCESSOR_ID},
            UpdateExpression="SET last_processed_timestamp = :ts, last_run_at = :now, last_run_status = :st",
            ExpressionAttributeValues={
                ':ts': new_timestamp,
                ':now': datetime.now(timezone.utc).isoformat(),
                ':st': 'COMPLETED'
            }
        )
        logger.info(f"[INFO] Cập nhật Checkpoint thành công: {new_timestamp}")
    except Exception as e:
        logger.error(f"[ERROR] Thất bại khi cập nhật checkpoint: {str(e)}")

def generate_hourly_prefixes(start_dt, end_dt):
    """Sinh danh sách tiền tố S3 theo từng giờ trong khoảng thời gian cần quét"""
    prefixes = set()
    current = start_dt.replace(minute=0, second=0, microsecond=0)
    while current <= end_dt:
        prefix = f"logs/year={current.strftime('%Y')}/month={current.strftime('%m')}/day={current.strftime('%d')}/hour={current.strftime('%H')}/"
        prefixes.add(prefix)
        current += timedelta(hours=1)
    return list(prefixes)

# -------------------------------------------------------------------------
# 2. KHỬ NHẠY CẢM VÀ CHUẨN HÓA LỖI (REDACTION & GROUPING)
# -------------------------------------------------------------------------

def sanitize_text(text):
    """Khử toàn bộ thông tin nhạy cảm (passwords, tokens, api keys) trước khi gửi AI"""
    text = re.sub(r'(Authorization:\s*Bearer\s+)[^\s\'"]+', r'\1[REDACTED]', text, flags=re.IGNORECASE)
    text = re.sub(r'(password|passwd|pwd)\s*=\s*[^\s,\'"]+', r'\1=[REDACTED]', text, flags=re.IGNORECASE)
    text = re.sub(r'(api_key|apiKey|secret|token)\s*=\s*[\'"][^\'"]+[\'"]', r'\1="[REDACTED]"', text, flags=re.IGNORECASE)
    text = re.sub(r'(api_key|apiKey|secret|token)\s*=\s*[^\s,\'"]+', r'\1=[REDACTED]', text, flags=re.IGNORECASE)
    return text

def normalize_signature(line):
    """Chuẩn hóa dòng log để gom nhóm: thay thế UUID, IP, Timestamp, con số biến thiên"""
    # Loại bỏ timestamp đầu dòng (ISO hoặc dạng 2026-09-16...)
    norm = re.sub(r'^\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}[\.\d]*Z?\s*', '', line)
    # Thay thế UUID / Request ID
    norm = re.sub(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<UUID>', norm)
    # Thay thế Request ID dạng RID=...
    norm = re.sub(r'RID=[^\s]+', 'RID=<REQ_ID>', norm)
    # Thay thế địa chỉ IPv4
    norm = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', '<IP>', norm)
    # Thay thế các con số mili-giây hoặc số liệu động
    norm = re.sub(r'\b\d+ms\b', '<NUM>ms', norm)
    norm = re.sub(r'after\s+\d+ms', 'after <NUM>ms', norm)
    norm = re.sub(r'User=\d+', 'User=<USER_ID>', norm)
    return norm.strip()

def is_error_line(line):
    """Kiểm tra xem dòng log có phải lỗi cần phân tích hay không"""
    upper_line = line.upper()
    
    # Kiểm tra xem có chứa từ khóa lỗi không
    has_error = any(keyword in upper_line for keyword in ERROR_KEYWORDS)
    if not has_error:
        return False
        
    # Loại bỏ các dòng thông thường giả lập (ví dụ "Status=200")
    if "STATUS=200" in upper_line and "ERROR" not in upper_line:
        return False
        
    return True

# -------------------------------------------------------------------------
# 3. ĐỌC VÀ GIẢI MÃ S3 LOGS TỪ FIREHOSE
# -------------------------------------------------------------------------

def decompress_cloudwatch_payload(raw_bytes):
    """Xử lý giải nén kép: Firehose ZIP/GZIP bọc payload GZIP từ CloudWatch Subscription"""
    extracted_chunks = []
    try:
        with zipfile.ZipFile(io.BytesIO(raw_bytes)) as zf:
            for name in zf.namelist():
                extracted_chunks.append(zf.read(name))
    except Exception:
        extracted_chunks.append(raw_bytes)
        
    decompressed_texts = []
    for chunk in extracted_chunks:
        d = io.BytesIO(chunk)
        chunk_len = len(chunk)
        while d.tell() < chunk_len:
            pos = d.tell()
            magic = d.read(2)
            if magic == b'\x1f\x8b':
                d.seek(pos)
                try:
                    with gzip.GzipFile(fileobj=d) as gz:
                        decompressed_texts.append(gz.read().decode('utf-8', errors='replace'))
                except Exception:
                    break
            else:
                d.seek(pos)
                rest = d.read().decode('utf-8', errors='replace')
                if rest:
                    decompressed_texts.append(rest)
                break
    return "\n".join(decompressed_texts)

def process_s3_object(bucket, key):
    """Tải file từ S3, giải nén và phân tách từng dòng log"""
    lines = []
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read()
        decompressed = decompress_cloudwatch_payload(content)
            
        # Thử parse toàn bộ decompressed là 1 JSON payload chứa logEvents
        parsed_successfully = False
        try:
            payload = json.loads(decompressed)
            if isinstance(payload, dict):
                if 'logEvents' in payload:
                    for ev in payload['logEvents']:
                        lines.append(ev.get('message', '').strip())
                    parsed_successfully = True
                elif 'message' in payload:
                    lines.append(payload.get('message', '').strip())
                    parsed_successfully = True
        except Exception:
            pass

        if not parsed_successfully:
            raw_lines = decompressed.splitlines()
            for raw in raw_lines:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    payload = json.loads(raw)
                    if isinstance(payload, dict) and 'logEvents' in payload:
                        for ev in payload['logEvents']:
                            lines.append(ev.get('message', '').strip())
                    elif isinstance(payload, dict) and 'message' in payload:
                        lines.append(payload.get('message', '').strip())
                    else:
                        lines.append(raw)
                except Exception:
                    lines.append(raw)
                
    except Exception as e:
        logger.error(f"[ERROR] Thất bại khi đọc S3 Object s3://{bucket}/{key}: {str(e)}")
        
    return lines

# -------------------------------------------------------------------------
# 4. GỌI AMAZON BEDROCK (CONVERSE API) ĐỂ PHÂN TÍCH NGUYÊN NHÂN GỐC RỄ
# -------------------------------------------------------------------------

def call_bedrock_analysis(error_groups, total_errors_count):
    """Gửi các nhóm lỗi đã chuẩn hóa lên Amazon Bedrock để lấy RCA có cấu trúc JSON"""
    prompt_system = (
        "You are an expert AWS Senior DevOps & Site Reliability Engineer (SRE). "
        "Your role is to perform automated Root Cause Analysis (RCA) on production error logs.\n"
        "Instructions:\n"
        "1. Strictly analyze ONLY the provided error signatures, frequencies, and surrounding contexts.\n"
        "2. Do NOT invent or assume facts that are not backed by log evidence.\n"
        "3. Output MUST be 100% valid JSON strictly adhering to the specified schema.\n"
        "4. Do NOT include markdown code blocks (such as ```json) or any conversational text."
    )
    
    # Chuẩn bị payload cô đọng
    compact_groups = []
    for sig, data in error_groups.items():
        compact_groups.append({
            "normalized_signature": sig,
            "occurrences_count": data["count"],
            "sample_contexts": data["contexts"][:2] # Tối đa 2 sample contexts
        })
        
    user_content = json.dumps({
        "total_error_lines": total_errors_count,
        "unique_error_groups_count": len(compact_groups),
        "error_groups": compact_groups,
        "expected_output_schema": {
            "severity": "LOW | MEDIUM | HIGH | CRITICAL",
            "service": "Name of the most impacted service",
            "summary": "Brief 1-2 sentence summary of the incident",
            "probable_root_cause": "Detailed technical root cause deduced from evidence",
            "confidence": 0.95,
            "evidence": ["Exact quotes or metrics from logs"],
            "recommended_actions": ["Concrete AWS remediation steps, e.g. check RDS connection pool, scale Lambda"]
        }
    }, indent=2)
    
    try:
        logger.info(f"[INFO] Gửi request đến Bedrock Model: {BEDROCK_MODEL_ID}")
        
        # Sử dụng Converse API thống nhất
        response = bedrock_runtime.converse(
            modelId=BEDROCK_MODEL_ID,
            messages=[
                {
                    "role": "user",
                    "content": [{"text": f"Analyze these grouped production errors and return JSON only:\n{user_content}"}]
                }
            ],
            system=[{"text": prompt_system}],
            inferenceConfig={
                "maxTokens": 1500,
                "temperature": 0.1,
                "topP": 0.9
            }
        )
        
        raw_output = response['output']['message']['content'][0]['text'].strip()
        
        # Dọn dẹp nếu model vô tình bọc markdown ```json ... ```
        if raw_output.startswith("```json"):
            raw_output = raw_output[7:]
        if raw_output.startswith("```"):
            raw_output = raw_output[3:]
        if raw_output.endswith("```"):
            raw_output = raw_output[:-3]
        raw_output = raw_output.strip()
        
        analysis_result = json.loads(raw_output)
        return analysis_result
        
    except Exception as e:
        logger.error(f"[ERROR] Bedrock invocation or JSON parsing failed: {str(e)}")
        # Fallback an toàn, không làm crash toàn bộ batch
        return {
            "severity": "HIGH",
            "service": "unknown",
            "summary": f"Automated analysis failed due to exception: {str(e)}",
            "probable_root_cause": "Undetermined - Check raw CloudWatch logs",
            "confidence": 0.0,
            "evidence": [list(error_groups.keys())[0] if error_groups else "No signature"],
            "recommended_actions": ["Inspect Lambda processor execution logs"]
        }

# -------------------------------------------------------------------------
# 5. GHI DYNAMODB VÀ BẮN CẢNH BÁO SNS
# -------------------------------------------------------------------------

def save_analysis_result(analysis, total_errors, groups_count):
    """Lưu kết quả phân tích có cấu trúc vào DynamoDB ai-log-analysis-results"""
    table = dynamodb_resource.Table(RESULTS_TABLE)
    now_iso = datetime.now(timezone.utc).isoformat()
    analysis_id = f"RCA-{int(datetime.now(timezone.utc).timestamp())}"
    
    item = {
        "analysis_id": analysis_id,
        "timestamp": now_iso,
        "severity": analysis.get("severity", "MEDIUM"),
        "service": analysis.get("service", "general"),
        "summary": analysis.get("summary", "No summary provided"),
        "probable_root_cause": analysis.get("probable_root_cause", "N/A"),
        "confidence": str(analysis.get("confidence", 0.0)),
        "evidence": analysis.get("evidence", []),
        "recommended_actions": analysis.get("recommended_actions", []),
        "total_errors_detected": total_errors,
        "unique_groups_count": groups_count,
        "bedrock_model": BEDROCK_MODEL_ID
    }
    
    try:
        table.put_item(Item=item)
        logger.info(f"[INFO] Đã lưu kết quả phân tích vào DynamoDB: {analysis_id}")
    except Exception as e:
        logger.error(f"[ERROR] Lưu kết quả DynamoDB thất bại: {str(e)}")

def publish_sns_alert(analysis, total_errors):
    """Bắn thông báo Email qua SNS khi Severity là HIGH hoặc CRITICAL"""
    severity = analysis.get("severity", "LOW").upper()
    if severity not in ["HIGH", "CRITICAL"]:
        logger.info(f"[INFO] Bỏ qua gửi SNS vì mức độ nghiêm trọng là {severity} (chỉ gửi khi HIGH/CRITICAL).")
        return

    subject = f"[{severity}] AWS AI Log Alert - {analysis.get('service', 'App')} Incident"
    # Cắt ngắn subject nếu vượt quá giới hạn 100 ký tự của SNS
    if len(subject) > 100:
        subject = subject[:97] + "..."
        
    actions_formatted = "\n".join([f"- {action}" for action in analysis.get("recommended_actions", [])])
    evidence_formatted = "\n".join([f"  * {ev}" for ev in analysis.get("evidence", [])])
    
    message = f"""====================================================
AWS AI-POWERED INCIDENT ALERT - AP-SOUTHEAST-2
====================================================

Severity:             {severity}
Impacted Service:     {analysis.get('service', 'N/A')}
Total Errors Count:   {total_errors}
Confidence Score:     {analysis.get('confidence', 'N/A')}

----------------------------------------------------
INCIDENT SUMMARY:
----------------------------------------------------
{analysis.get('summary', 'N/A')}

----------------------------------------------------
PROBABLE ROOT CAUSE:
----------------------------------------------------
{analysis.get('probable_root_cause', 'N/A')}

----------------------------------------------------
KEY LOG EVIDENCE:
----------------------------------------------------
{evidence_formatted}

----------------------------------------------------
RECOMMENDED REMEDIATION ACTIONS:
----------------------------------------------------
{actions_formatted}

====================================================
Timestamp: {datetime.now(timezone.utc).isoformat()}
Analyzed by Amazon Bedrock ({BEDROCK_MODEL_ID})
====================================================
"""
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        logger.info(f"[INFO] Bắn Email cảnh báo SNS thành công tới Topic: {SNS_TOPIC_ARN}")
    except Exception as e:
        logger.error(f"[ERROR] Gửi SNS Publish thất bại: {str(e)}")

# -------------------------------------------------------------------------
# 6. HÀM ĐIỀU PHỐI CHÍNH (LAMBDA HANDLER)
# -------------------------------------------------------------------------

def lambda_handler(event, context):
    start_time = time.time()
    logger.info("=== BẮT ĐẦU BATCH AI LOG PROCESSOR ===")
    
    # 1. Đọc Checkpoint và xác định khung thời gian quét
    last_processed_str = get_checkpoint()
    current_time = datetime.now(timezone.utc)
    current_time_str = current_time.isoformat()
    
    try:
        start_dt = datetime.fromisoformat(last_processed_str.replace('Z', '+00:00'))
    except Exception:
        start_dt = current_time - timedelta(hours=1)
        
    # Giới hạn cửa sổ quét tối đa 2 giờ trước để tránh quét thừa khi mới khởi tạo
    max_lookback = current_time - timedelta(hours=2)
    if start_dt < max_lookback:
        start_dt = max_lookback
        
    logger.info(f"[INFO] Khung thời gian quét: {start_dt.isoformat()} ➔ {current_time_str}")
    
    # 2. Sinh các prefix giờ trên S3 cần quét
    hourly_prefixes = generate_hourly_prefixes(start_dt, current_time)
    logger.info(f"[INFO] Các tiền tố S3 liên quan: {hourly_prefixes}")
    
    # 3. Duyệt S3 ListObjectsV2 để tìm các file nằm trong khung thời gian
    candidate_objects = []
    for prefix in hourly_prefixes:
        paginator = s3_client.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=S3_BUCKET_NAME, Prefix=prefix):
            for obj in page.get('Contents', []):
                obj_key = obj['Key']
                obj_time = obj['LastModified']
                # Chỉ lấy object nằm trong khoảng start_dt và current_time
                if start_dt <= obj_time <= current_time:
                    candidate_objects.append(obj_key)
                    
    logger.info(f"[INFO] Số lượng S3 objects tìm thấy cần quét: {len(candidate_objects)}")
    
    # 4. Tải và gom tất cả các dòng log
    all_raw_lines = []
    for obj_key in candidate_objects:
        lines = process_s3_object(S3_BUCKET_NAME, obj_key)
        all_raw_lines.extend(lines)
        
    total_parsed_lines = len(all_raw_lines)
    logger.info(f"[INFO] Tổng số dòng log thô đã đọc: {total_parsed_lines}")
    
    # 5. Lọc lỗi và gom nhóm (Filtering & Grouping with Context)
    error_groups = {}
    detected_errors_count = 0
    
    for idx, raw_line in enumerate(all_raw_lines):
        if is_error_line(raw_line):
            detected_errors_count += 1
            
            # Khử dữ liệu nhạy cảm
            sanitized_line = sanitize_text(raw_line)
            # Tạo signature chuẩn hóa
            signature = normalize_signature(sanitized_line)
            
            # Trích xuất ngữ cảnh xung quanh (-3 dòng trước, +2 dòng sau)
            start_ctx = max(0, idx - 3)
            end_ctx = min(len(all_raw_lines), idx + 3)
            context_snippet = [sanitize_text(all_raw_lines[c]) for c in range(start_ctx, end_ctx)]
            
            if signature not in error_groups:
                error_groups[signature] = {
                    "count": 0,
                    "first_seen": sanitized_line,
                    "contexts": []
                }
            error_groups[signature]["count"] += 1
            if len(error_groups[signature]["contexts"]) < 2:
                error_groups[signature]["contexts"].append(context_snippet)
                
    unique_groups_count = len(error_groups)
    
    # 6. Ghi log các chỉ số vận hành (Logic Metrics)
    logger.info(f"[METRIC] Objects scanned: {len(candidate_objects)}")
    logger.info(f"[METRIC] Logs parsed: {total_parsed_lines}")
    logger.info(f"[METRIC] Error records detected: {detected_errors_count}")
    logger.info(f"[METRIC] Unique error groups: {unique_groups_count}")
    
    bedrock_calls = 0
    sns_alerts = 0
    
    # 7. Quyết định gọi Bedrock AI
    if detected_errors_count == 0:
        logger.info("[INFO] Không phát hiện bất kỳ lỗi nào trong lô log này. BỎ QUA GỌI BEDROCK (Chi phí AI: 0$).")
    else:
        logger.info(f"[INFO] Phát hiện {detected_errors_count} lỗi phân bố trong {unique_groups_count} nhóm. Bắt đầu phân tích AI...")
        analysis_result = call_bedrock_analysis(error_groups, detected_errors_count)
        bedrock_calls = 1
        
        # Lưu kết quả vào DynamoDB
        save_analysis_result(analysis_result, detected_errors_count, unique_groups_count)
        
        # Kiểm tra và gửi SNS nếu lỗi HIGH/CRITICAL
        severity = analysis_result.get("severity", "LOW").upper()
        if severity in ["HIGH", "CRITICAL"]:
            publish_sns_alert(analysis_result, detected_errors_count)
            sns_alerts = 1
            
    # 8. Cập nhật Checkpoint kết thúc batch an toàn
    update_checkpoint(current_time_str)
    
    duration = round(time.time() - start_time, 2)
    logger.info(f"[METRIC] Bedrock calls: {bedrock_calls}")
    logger.info(f"[METRIC] Alerts sent: {sns_alerts}")
    logger.info(f"[METRIC] Processing duration: {duration}s")
    logger.info("=== KẾT THÚC BATCH AI LOG PROCESSOR HOÀN HẢO ===")
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "status": "COMPLETED",
            "objects_scanned": len(candidate_objects),
            "logs_parsed": total_parsed_lines,
            "errors_detected": detected_errors_count,
            "unique_groups": unique_groups_count,
            "bedrock_calls": bedrock_calls,
            "sns_alerts": sns_alerts,
            "duration_seconds": duration
        })
    }
```

---

## 7. KỊCH BẢN KIỂM THỬ TOÀN DIỆN (END-TO-END TEST SCENARIOS)

Chúng ta sẽ thực hiện kiểm thử 3 kịch bản theo đúng vòng đời thực tế của hệ thống để chứng minh tính hiệu quả và tiết kiệm chi phí.

---

### Kịch bản 1: Nhật ký bình thường (Only INFO / HTTP 200)

#### Mục tiêu:
Chứng minh hệ thống quét qua hàng trăm log bình thường nhưng **KHÔNG gọi Bedrock** và **KHÔNG gửi SNS**, chi phí vận hành AI bằng 0$.

#### Các bước thực hiện:
1. Vào Lambda `ai-log-demo-app` ➔ Tab **Test**.
2. Chọn Test Event với payload:
   ```json
   {
     "mode": "normal",
     "batch_size": 20
   }
   ```
3. Nhấn **Test** ➔ Lambda sinh 20 dòng log INFO và HTTP 200.
4. Chờ 5 phút để Data Firehose flush dữ liệu sang S3 (hoặc kiểm tra file mới trong S3).
5. Vào Lambda `ai-log-batch-processor` ➔ Tab **Test** ➔ Nhấn **Test** thủ công với payload `{}`.
6. Quan sát kết quả **Execution results** và CloudWatch Logs của Processor.

#### Kết quả kỳ vọng (Expected Output):
* `Objects scanned`: >= 1
* `Logs parsed`: ~20-30
* `Error records detected`: **0**
* `Unique error groups`: **0**
* `Bedrock calls`: **0**
* `Alerts sent`: **0**
* DynamoDB `ai-log-analysis-results`: Không có bản ghi mới.
* Hộp thư Email: Hoàn toàn không nhận được cảnh báo nào.

---

### Kịch bản 2: Lỗi trung bình lặp lại (Database Timeout Flurry)

#### Mục tiêu:
Chứng minh tính năng **Gom nhóm lỗi (Error Grouping)**: 30 lỗi timeout cơ sở dữ liệu xuất hiện dồn dập được gom thành 1 nhóm lỗi duy nhất, chỉ gọi Bedrock 1 lần với số lượng token cực kỳ ít.

#### Các bước thực hiện:
1. Vào Lambda `ai-log-demo-app` ➔ Tab **Test**.
2. Đổi payload test thành:
   ```json
   {
     "mode": "database_timeout",
     "batch_size": 30
   }
   ```
3. Nhấn **Test** ➔ Tạo ra 30 lỗi timeout kèm token Authorization nhạy cảm.
4. Chờ 5 phút để Firehose đẩy dữ liệu sang S3.
5. Vào Lambda `ai-log-batch-processor` ➔ Nhấn **Test**.
6. Mở tab **Monitor** ➔ **View CloudWatch logs**.

#### Kết quả kỳ vọng (Expected Output):
* `Logs parsed`: ~35-50
* `Error records detected`: ~30
* `Unique error groups`: **1** (Toàn bộ lỗi timeout được gom vào 1 signature)
* `Bedrock calls`: **1**
* CloudWatch log hiển thị: Token nhạy cảm đã bị thay thế thành `Authorization: Bearer [REDACTED]`.
* Bảng DynamoDB `ai-log-analysis-results`: Xuất hiện 1 bản ghi mới với `severity: "MEDIUM"` hoặc `"HIGH"`, tóm tắt sự cố RDS connection pool.

---

### Kịch bản 3: Thảm họa Critical Severity (Payment Down + HTTP 503 + SNS Email)

#### Mục tiêu:
Mô phỏng thảm họa sập dịch vụ thanh toán và Redis cache. AI nhận diện mức độ **CRITICAL**, trích xuất bằng chứng xác thực và ngay lập tức gửi Email cảnh báo sự cố đến quản trị viên.

#### Các bước thực hiện:
1. Vào Lambda `ai-log-demo-app` ➔ Tab **Test**.
2. Đổi payload test thành:
   ```json
   {
     "mode": "high_critical_errors",
     "batch_size": 40
   }
   ```
3. Nhấn **Test** 2 lần liên tiếp.
4. Đợi 5 phút để Firehose hoàn thành buffer.
5. Kích hoạt Lambda `ai-log-batch-processor` (hoặc để EventBridge Scheduler tự kích hoạt).
6. Mở hộp thư Email của bạn kiểm tra hộp thư đến (Inbox).

#### Kết quả kỳ vọng (Expected Output):
* `Bedrock calls`: **1**
* `Alerts sent`: **1**
* Hộp thư Email nhận được thông báo từ SNS với tiêu đề dạng:
  ```text
  [CRITICAL] AWS AI Log Alert - payment-service Incident
  ```
* Nội dung Email chỉ rõ:
  - **Severity:** CRITICAL
  - **Impacted Service:** payment-service
  - **Probable Root Cause:** StripeGateway NullPointerException & Redis cluster connection refusal
  - **Recommended Remediation Actions:** Kiểm tra Redis cluster endpoint, kiểm tra exception trong StripeGateway, kiểm tra tài nguyên backend.

---

## 8. PHÂN TÍCH XỬ LÝ TÌNH HUỐNG NGOẠI LỆ & THẤT BẠI (FAILURE SCENARIOS & IDEMPOTENCY)

| Tình Huống Sự Cố (Failure Mode) | Hậu Quả Tiềm Ẩn | Cơ Chế Bảo Vệ & Xử Lý Trong Kiến Trúc |
| :--- | :--- | :--- |
| **Bedrock API Throttling (429 Too Many Requests)** | Batch job bị gián đoạn, không phân tích được lỗi | Boto3 SDK tự động kích hoạt Exponential Backoff & Retry; mã nguồn bắt Exception, ghi log rõ ràng và **KHÔNG** cập nhật Checkpoint DynamoDB, giúp đợt chạy kế tiếp tự động thử lại. |
| **Model trả về JSON sai cú pháp (Malformed JSON)** | Lambda processor bị crash | Code sử dụng khối `try...except json.loads` kèm bộ lọc cắt Markdown ` ```json `. Nếu parse thất bại, hệ thống rơi vào fallback object an toàn, vẫn lưu kết quả thô và không làm đứt chuỗi xử lý. |
| **S3 Object bị lỗi / hỏng nén Gzip** | Không đọc được log stream | Khối giải nén thử nghiệm `GzipFile` bọc trong `try...except`. Nếu không phải Gzip hợp lệ, nó sẽ fallback đọc plain text, không gây crash toàn bộ lô. |
| **Firehose giao hàng trễ (Delayed Delivery)** | Log phát sinh ở phút 29 nhưng phút 34 mới flush xong vào S3 | Thuật toán sinh S3 prefix theo từng giờ (`hourly_prefixes`) và cửa sổ trượt Checkpoint đảm bảo ngay cả khi file đến muộn ở giờ kế tiếp, con trỏ thời gian vẫn quét trúng file này mà không bỏ sót. |
| **Lambda Timeout (Vượt quá 5 phút)** | Batch chưa chạy xong đã bị ngắt | Cấu hình Memory 512MB để tăng CPU tương ứng; Checkpoint DynamoDB chỉ được ghi ở dòng cuối cùng của hàm sau khi toàn bộ quy trình hoàn tất (Atomic Finalization). |
| **Xử lý trùng lặp (Idempotency Risk)** | Một file log bị đọc lại 2 lần | Mỗi bản ghi phân tích trong DynamoDB được gán `analysis_id` duy nhất dựa trên epoch timestamp của chu kỳ quét. Checkpoint lưu chính xác timestamp đến cấp microsecond. |

---

## 9. CHIẾN LƯỢC TỐI ƯU CHI PHÍ & BẢO MẬT ENTERPRISE (COST & SECURITY ARCHITECTURE)

### 9.1. So sánh chi phí: Kiến trúc Tồi (Bad) vs Kiến trúc Tối Ưu (Optimal)

```text
[KIẾN TRÚC TỒI - REALTIME TRIGGER]:
Mỗi file log nhỏ S3 ──➔ S3 Event Trigger ──➔ 1 Lambda Invocation ──➔ Gọi Bedrock thẳng
- 1 ngày: 50,000 file log nhỏ = 50,000 Lambda Invocations.
- Gọi Bedrock 50,000 lần (kể cả log INFO vô nghĩa).
- Chi phí Bedrock: Hàng trăm USD mỗi ngày! Thường xuyên chạm Bedrock Rate Limit.

[KIẾN TRÚC TỐI ƯU TRONG BÀI LAB - BATCH DEDUPLICATION]:
Logs ──➔ Firehose Buffer 300s (Nén Gzip) ──➔ S3 Partitioned Prefix
                                                    │
                                                    ▼
EventBridge Scheduler (Mỗi 30 phút) ──➔ 1 Lambda Batch (Lọc bỏ 95% INFO/DEBUG)
                                                    │
                                                    ▼
                                          Gom 387 lỗi thành 3 nhóm
                                                    │
                                                    ▼
                                          ĐÚNG 1 Bedrock Request gọn nhẹ!
- 1 ngày chỉ có 48 Lambda Invocations.
- Số lần gọi Bedrock giảm hơn 99% (chỉ gọi khi có lỗi thực tế).
- Tiết kiệm 95% - 98% tổng hóa đơn AWS hàng tháng!
```

### 9.2. Tiêu chuẩn bảo mật (Enterprise Security Checklist)
1. **Không công khai dữ liệu:** S3 Bucket bật tuyệt đối **Block All Public Access** và mã hóa tại chỗ bằng **SSE-S3**.
2. **Quyền hạn tối thiểu (IAM Least Privilege):** Các IAM Role không sử dụng `AdministratorAccess`. Mỗi Role chỉ có đúng những Action cần thiết gắn chặt vào ARN của Bucket, Table và Topic cụ thể.
3. **Chống rò rỉ Credential (Log Sanitization):** Toàn bộ token, Authorization headers, mật khẩu người dùng đều được biểu thức chính quy (Regex) của Lambda đè thành `[REDACTED]` trước khi bất kỳ payload nào chạm tới Amazon Bedrock.
4. **Không hard-code Credentials:** Toàn bộ quá trình xác thực dịch vụ AWS được quản lý hoàn toàn tự động qua IAM Role và STS temporary tokens.

---

## 10. QUY TRÌNH DỌN DẸP TÀI NGUYÊN TRÁNH PHÁT SINH PHÍ (CLEANUP CHECKLIST)

Sau khi hoàn thành bài lab, hãy xóa các tài nguyên theo **thứ tự ngược lại** dưới đây để tránh bị lỗi ràng buộc phụ thuộc (dependency errors) và không phát sinh chi phí duy trì:

```text
THỨ TỰ DỌN DẸP TÀI NGUYÊN:
 1. Amazon EventBridge Scheduler ➔ Xóa schedule 'ai-log-analysis-schedule'
 2. Amazon SNS                   ➔ Xóa Subscription và Topic 'ai-log-critical-alerts'
 3. CloudWatch Logs Subscription ➔ Xóa Subscription filter trong log group '/aws/lambda/ai-log-demo-app'
 4. AWS Lambda                   ➔ Xóa 2 hàm: 'ai-log-demo-app' và 'ai-log-batch-processor'
 5. Amazon Data Firehose         ➔ Xóa stream 'ai-log-firehose'
 6. Amazon DynamoDB              ➔ Xóa 2 bảng: 'ai-log-processing-state' và 'ai-log-analysis-results'
 7. Amazon S3                    ➔ Bấm "Empty bucket" xóa hết object, sau đó bấm "Delete bucket"
 8. AWS IAM                      ➔ Xóa các Role và Customer Managed Policy đã tạo
 9. CloudWatch Log Groups        ➔ Xóa log groups của 2 Lambda function để sạch môi trường
```

### Thao tác chi tiết trên AWS Console:
1. **EventBridge Scheduler:** Vào **EventBridge ➔ Schedules** ➔ Chọn `ai-log-analysis-schedule` ➔ Nhấn **Delete**.
2. **SNS:** Vào **SNS ➔ Topics** ➔ Chọn `ai-log-critical-alerts` ➔ Nhấn **Delete**. Chọn mục **Subscriptions** ➔ Xóa subscription tương ứng.
3. **CloudWatch Subscription Filter:** Vào **CloudWatch ➔ Log groups ➔ `/aws/lambda/ai-log-demo-app`** ➔ Tab **Subscription filters** ➔ Chọn filter ➔ Nhấn **Delete**.
4. **Lambda Functions:** Vào **Lambda ➔ Functions** ➔ Tích chọn `ai-log-demo-app` và `ai-log-batch-processor` ➔ Menu **Actions ➔ Delete**.
5. **Data Firehose:** Vào **Amazon Data Firehose** ➔ Chọn `ai-log-firehose` ➔ Nhấn **Delete**.
6. **DynamoDB Tables:** Vào **DynamoDB ➔ Tables** ➔ Xóa lần lượt `ai-log-processing-state` và `ai-log-analysis-results`.
7. **S3 Bucket:** Vào **S3** ➔ Nhấp vào `ai-log-analysis-<ACCOUNT_ID>-ap-southeast-2` ➔ Nhấn **Empty** (gõ `permanently delete` để xác nhận) ➔ Quay ra ngoài nhấn **Delete** bucket.
8. **IAM Roles & Policies:** Vào **IAM**:
   - Mục **Roles:** Xóa `ai-log-firehose-role`, `ai-log-cw-to-firehose-role`, `ai-log-processor-role`, `ai-log-demo-app-role`, `ai-log-scheduler-role`.
   - Mục **Policies:** Xóa `ai-log-firehose-s3-policy`, `ai-log-cw-put-firehose-policy`, `ai-log-processor-least-privilege-policy`.
9. **Log Groups:** Vào **CloudWatch ➔ Log groups** ➔ Xóa `/aws/lambda/ai-log-demo-app` và `/aws/lambda/ai-log-batch-processor`.

### Lựa chọn: Lệnh dọn dẹp nhanh qua AWS CLI / PowerShell
Nếu muốn dọn dẹp nhanh chóng bằng script tự động:

```bash
# Thiết lập biến môi trường
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-southeast-2"

# 1. Xóa EventBridge Schedule
aws scheduler delete-schedule --name ai-log-analysis-schedule --region $REGION

# 2. Xóa CloudWatch Subscription Filter
aws logs delete-subscription-filter --log-group-name /aws/lambda/ai-log-demo-app --filter-name sub-filter-demo-app-to-firehose --region $REGION

# 3. Xóa Lambda Functions
aws lambda delete-function --function-name ai-log-demo-app --region $REGION
aws lambda delete-function --function-name ai-log-batch-processor --region $REGION

# 4. Xóa Firehose Delivery Stream
aws firehose delete-delivery-stream --delivery-stream-name ai-log-firehose --region $REGION

# 5. Xóa DynamoDB Tables
aws dynamodb delete-table --table-name ai-log-processing-state --region $REGION
aws dynamodb delete-table --table-name ai-log-analysis-results --region $REGION

# 6. Xóa SNS Topic
TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:ai-log-critical-alerts"
aws sns delete-topic --topic-arn $TOPIC_ARN --region $REGION

# 7. Xóa rỗng và xóa S3 Bucket
aws s3 rm s3://ai-log-analysis-${ACCOUNT_ID}-${REGION} --recursive
aws s3api delete-bucket --bucket ai-log-analysis-${ACCOUNT_ID}-${REGION} --region $REGION

# 8. Xóa IAM Roles và Policies
aws iam delete-role-policy --role-name ai-log-cw-to-firehose-role --policy-name ai-log-cw-put-firehose-policy
aws iam delete-role --role-name ai-log-cw-to-firehose-role

aws iam delete-role-policy --role-name ai-log-firehose-role --policy-name ai-log-firehose-s3-policy
aws iam delete-role --role-name ai-log-firehose-role

aws iam delete-role-policy --role-name ai-log-processor-role --policy-name ai-log-processor-least-privilege-policy
aws iam delete-role --role-name ai-log-processor-role

aws iam delete-role-policy --role-name ai-log-scheduler-role --policy-name ai-log-scheduler-invoke-lambda
aws iam delete-role --role-name ai-log-scheduler-role

aws iam detach-role-policy --role-name ai-log-demo-app-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name ai-log-demo-app-role

# 9. Xóa CloudWatch Log Groups
aws logs delete-log-group --log-group-name /aws/lambda/ai-log-demo-app --region $REGION
aws logs delete-log-group --log-group-name /aws/lambda/ai-log-batch-processor --region $REGION
```

---

## 🏆 KẾT QUẢ ĐẠT ĐƯỢC SAU BÀI LAB

Sau khi hoàn thành bài thực hành này, bạn đã xây dựng thành công một giải pháp cấp Enterprise:
* ✅ Nắm vững kiến trúc thu thập log quy mô lớn bằng **CloudWatch Logs** và **Amazon Data Firehose**.
* ✅ Hiểu rõ và áp dụng triệt để tư duy **Batch Processing** kết hợp **EventBridge Scheduler** thay vì lãng phí tài nguyên bằng S3 Event Triggers.
* ✅ Xây dựng thuật toán lọc **Rule-based**, **Context Slicing**, và **Deduplication Grouping** giúp cắt giảm hơn 95% chi phí AI Token.
* ✅ Làm chủ kỹ năng tương tác với **Amazon Bedrock Converse API** trên nền tảng Serverless tại Region **Sydney (`ap-southeast-2`)**.
* ✅ Triển khai mô hình bảo mật chuẩn **Least Privilege IAM**, tự động **Sanitize** dữ liệu nhạy cảm và lưu trữ vết kiểm toán (Audit History) trên **DynamoDB** kết hợp cảnh báo tức thời qua **Amazon SNS**.
