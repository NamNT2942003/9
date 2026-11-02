# BÀI TẬP 3: XÂY DỰNG PIPELINE CI/CD KẾT NỐI POSTGRESQL TRONG GITLAB CI

## 1. Tình huống nghiệp vụ & Mục tiêu
- **Dự án**: Hệ thống Microservices "Quản lý nhân sự" (sử dụng Spring Boot & cơ sở dữ liệu PostgreSQL).
- **Vấn đề thực tế**: Các commit code gây lỗi do không được kiểm thử logic truy vấn Database kỹ càng trước khi đóng gói triển khai.
- **Giải pháp**: Thiết lập luồng CI Pipeline tự động:
  1. **Stage `test`**: Tự động dựng một container Database tạm thời (`postgres:14-alpine`) bằng từ khóa `services:`, inject cấu hình kết nối và chạy Integration Test bằng `./gradlew test`.
  2. **Stage `build`**: Nếu và chỉ nếu tất cả các bài test vượt qua, pipeline mới chuyển sang stage build, thực thi `./gradlew build -x test` để đóng gói file `.jar`.
  3. **Lưu trữ `artifacts`**: Lưu trữ thư mục `build/libs/*.jar` trong vòng 1 ngày để phục vụ deploy/demo.

---

## 2. File `.gitlab-ci.yml` hoàn chỉnh

```yaml
# ========================================================
# GitLab CI/CD Pipeline - Quản lý nhân sự / Microservices
# Bài tập 3: Xây dựng Pipeline CI/CD kết nối PostgreSQL
# ========================================================

# Sử dụng image Gradle tích hợp sẵn JDK 17
image: gradle:7.6-jdk17

# Định nghĩa 2 stages chạy tuần tự: test trước, build sau
stages:
  - test
  - build

# Cấp quyền thực thi cho Gradle Wrapper trước khi chạy các script
before_script:
  - chmod +x ./gradlew

# ========================================================
# Stage 1: Chạy Unit & Integration Test với PostgreSQL Service
# ========================================================
test_job:
  stage: test
  # Khởi chạy Database container chạy song song trong suốt quá trình test
  services:
    - name: postgres:14-alpine
      alias: postgres
  # Cấu hình các biến môi trường cho PostgreSQL và Spring Boot Datasource
  variables:
    POSTGRES_DB: hrm_db
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: password123
    SPRING_DATASOURCE_URL: "jdbc:postgresql://postgres:5432/hrm_db"
    SPRING_DATASOURCE_USERNAME: "postgres"
    SPRING_DATASOURCE_PASSWORD: "password123"
  script:
    - ./gradlew test

# ========================================================
# Stage 2: Đóng gói ứng dụng thành file JAR và lưu trữ artifact
# Chỉ thực thi khi stage test hoàn thành thành công
# ========================================================
build_job:
  stage: build
  script:
    - ./gradlew build -x test
  artifacts:
    name: "personnel-service-build-$CI_COMMIT_SHORT_SHA"
    paths:
      - build/libs/*.jar
    expire_in: 1 day
```

---

## 3. Phân tích cơ chế kỹ thuật & Keywords cốt lõi

### 🔗 1. Cơ chế chạy tuần tự giữa `test` và `build`
- Khai báo dưới `stages:`:
  ```yaml
  stages:
    - test
    - build
  ```
- **Nguyên lý hoạt động**: GitLab CI mặc định thực thi các stage theo đúng thứ tự đã khai báo.
  - Job thuộc stage `test` sẽ chạy đầu tiên.
  - Nếu `test_job` gặp lỗi (thất bại ở test case nào đó), pipeline sẽ lập tức **dừng lại** (fail fast). Job `build_job` thuộc stage `build` sẽ bị đánh dấu `canceled` / `skipped`.
  - Nhờ đó, ngăn chặn hoàn toàn việc đóng gói và phát hành mã nguồn lỗi ra môi trường thực tế.

### 🐘 2. Cơ chế `services` trong GitLab CI
- **Bản chất**: Từ khóa `services:` cho phép khởi chạy thêm các Docker container phụ trợ (như PostgreSQL, MySQL, Redis, MongoDB) chạy song song và kết nối với container chính của job qua một mạng Docker nội bộ (bridge network).
- **Phân giải tên miền (DNS Hostname)**:
  - Khi khai báo `postgres:14-alpine` (với alias `postgres`), container chính có thể truy cập Database qua địa chỉ:
    `postgres:5432`
  - Vì vậy, biến môi trường `SPRING_DATASOURCE_URL` được định nghĩa là `jdbc:postgresql://postgres:5432/hrm_db`.
- **Vòng đời (Lifecycle)**: Container PostgreSQL tự động khởi tạo khi job `test` bắt đầu và được dọn dẹp (tự động xóa bỏ hoàn toàn) ngay khi job kết thúc, không chiếm dụng tài nguyên máy chủ.

### 🔐 3. Cấu hình biến môi trường (`variables`)
- Image `postgres` chính thức trên Docker Hub đọc các biến môi trường sau để tự động khởi tạo cơ sở dữ liệu khi khởi động:
  - `POSTGRES_DB`: Tên cơ sở dữ liệu (`hrm_db`).
  - `POSTGRES_USER`: Tên tài khoản quản trị (`postgres`).
  - `POSTGRES_PASSWORD`: Mật khẩu kết nối (`password123`).
- Ứng dụng Spring Boot tự động nhận các biến `SPRING_DATASOURCE_*` để kết nối vào Database tương ứng.

### 📦 4. Quản lý bản build với `artifacts`
- **Mục đích**: Lưu giữ file kết quả build (`.jar`) được sinh ra bởi câu lệnh `./gradlew build -x test`.
- **Cấu hình**:
  - `paths: - build/libs/*.jar`: Chỉ định chính xác vị trí file JAR được tạo ra bởi Gradle.
  - `expire_in: 1 day`: Thiết lập thời gian lưu trữ file trên GitLab/CI server là 1 ngày, vừa đủ để đội vận hành tải về deploy hoặc demo, đồng thời tiết kiệm dung lượng lưu trữ của hệ thống CI.
