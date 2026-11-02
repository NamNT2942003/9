# BÀI TẬP 4: ĐẨY DOCKER IMAGE LÊN DOCKER HUB THÔNG QUA GITLAB CI

## 1. Tình huống nghiệp vụ & Mục tiêu
- **Mục tiêu**: Tự động hóa quá trình đóng gói artifact `.jar` từ stage `build` thành Docker Image và push lên **Docker Hub** công khai hoặc tổ chức.
- **Yêu cầu bảo mật cốt lõi**: Tuyệt đối **không hard-code** thông tin đăng nhập (`username`, `password`/`access token`) vào mã nguồn hoặc file cấu hình YAML. Toàn bộ thông tin nhạy cảm phải được quản lý qua **GitLab CI/CD Variables** (Masked Variables).

---

## 2. File `.gitlab-ci.yml` hoàn chỉnh

```yaml
# ========================================================
# GitLab CI/CD Pipeline - Microservices Platform
# Bài tập 4: Đẩy Docker Image lên Docker Hub qua GitLab CI
# ========================================================

# Danh sách các stages thực thi tuần tự: test -> build -> dockerize
stages:
  - test
  - build
  - dockerize

# ========================================================
# Stage 1: Chạy Unit & Integration Test với PostgreSQL Service
# ========================================================
test_job:
  stage: test
  image: gradle:7.6-jdk17
  services:
    - name: postgres:14-alpine
      alias: postgres
  variables:
    POSTGRES_DB: hrm_db
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: password123
    SPRING_DATASOURCE_URL: "jdbc:postgresql://postgres:5432/hrm_db"
    SPRING_DATASOURCE_USERNAME: "postgres"
    SPRING_DATASOURCE_PASSWORD: "password123"
  before_script:
    - chmod +x ./gradlew
  script:
    - ./gradlew test

# ========================================================
# Stage 2: Đóng gói ứng dụng thành file JAR và lưu trữ artifact
# ========================================================
build_job:
  stage: build
  image: gradle:7.6-jdk17
  before_script:
    - chmod +x ./gradlew
  script:
    - ./gradlew build -x test
  artifacts:
    name: "payment-service-build-$CI_COMMIT_SHORT_SHA"
    paths:
      - build/libs/*.jar
    expire_in: 1 day

# ========================================================
# Stage 3: Build Docker Image và Push lên Docker Hub (Docker-in-Docker)
# ========================================================
dockerize_job:
  stage: dockerize
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  variables:
    # Cấu hình biến môi trường cho Docker daemon (tắt TLS certs để DinD kết nối qua daemon port tiêu chuẩn)
    DOCKER_TLS_CERTDIR: ""
    DOCKER_DRIVER: overlay2
    IMAGE_NAME: "$DOCKER_USERNAME/payment-service"
  dependencies:
    - build_job
  before_script:
    # Đăng nhập an toàn vào Docker Hub sử dụng CI/CD Variables (không lộ credentials)
    - echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
  script:
    # Build Docker Image từ Dockerfile và file JAR lấy từ artifacts
    - docker build -t "$IMAGE_NAME:$CI_COMMIT_SHORT_SHA" -t "$IMAGE_NAME:latest" .
    # Push image lên Docker Hub với cả commit SHA tag và latest tag
    - docker push "$IMAGE_NAME:$CI_COMMIT_SHORT_SHA"
    - docker push "$IMAGE_NAME:latest"
```

---

## 3. Phân tích các kỹ thuật then chốt

### 🐳 1. Kỹ thuật Docker-in-Docker (DinD)
- **Vấn đề**: Bản thân GitLab Runner đang chạy bên trong một Docker container. Để có thể chạy được lệnh `docker build` và `docker push`, container này cần có Docker CLI và quyền giao tiếp với một Docker Daemon.
- **Giải pháp**:
  - `image: docker:24.0.5`: Cung cấp công cụ dòng lệnh Docker CLI.
  - `services: - docker:24.0.5-dind`: Khởi chạy một Docker Daemon độc lập bên trong container phụ trợ.
  - `DOCKER_TLS_CERTDIR: ""`: Tắt xác thực TLS cục bộ giữa Docker CLI và DinD service để đơn giản hóa giao tiếp mạng nội bộ trong runner.

### 🔑 2. Quản lý bí mật bằng CI/CD Variables
- Tuyệt đối không lưu mật khẩu vào file Git.
- Khai báo 2 biến tại mục **Settings > CI/CD > Variables** của repository GitLab:
  1. `DOCKER_USERNAME`: Tên tài khoản trên Docker Hub.
  2. `DOCKER_PASSWORD`: Personal Access Token (hoặc mật khẩu tài khoản) Docker Hub.
- **Tùy chọn bảo mật**:
  - Bật tính năng **Mask variable** để GitLab tự động ẩn giá trị biến này khỏi job log, ngăn chặn việc vô tình in token/password ra console.
  - Bật **Protected variable** nếu chỉ muốn deploy trên các branch được bảo vệ (như `main`).

### 📦 3. Kế thừa Artifacts từ stage `build`
- Khai báo `dependencies: [build_job]` giúp `dockerize_job` tự động tải về thư mục `build/libs/*.jar` được đóng gói từ stage trước.
- Khi lệnh `docker build` chạy, `Dockerfile` sẽ sao chép file `build/libs/payment-service-1.0.0.jar` vào image mà không cần phải compile lại mã nguồn Java một lần nữa, giúp tiết kiệm tối đa thời gian pipeline.

### 🏷️ 4. Chiến lược gắn Tag Image (`Tagging Strategy`)
Pipeline gắn cùng lúc 2 tag:
1. `$IMAGE_NAME:$CI_COMMIT_SHORT_SHA`: Giúp định danh chính xác phiên bản image gắn liền với commit Git tương ứng (phục vụ traceability, rollback khi cần).
2. `$IMAGE_NAME:latest`: Luôn trỏ tới phiên bản mới nhất vừa được build thành công, thuận tiện cho việc pull và deploy tự động.

---

## 4. Hướng dẫn thiết lập CI/CD Variables trên GitLab

1. Truy cập vào dự án trên GitLab: **Settings** ➔ **CI/CD**.
2. Tìm đến mục **Variables** và nhấn **Expand**.
3. Nhấn nút **Add variable** và điền 2 biến:
   - **Biến 1**:
     - *Key*: `DOCKER_USERNAME`
     - *Value*: `<tên_tài_khoản_docker_hub>` (Ví dụ: `namnt2942003`)
     - *Type*: Variable
     - *Flags*: Bỏ chọn Protect (hoặc chọn nếu chạy trên nhánh protected).
   - **Biến 2**:
     - *Key*: `DOCKER_PASSWORD`
     - *Value*: `<docker_hub_personal_access_token>`
     - *Type*: Variable
     - *Flags*: Đánh dấu tích vào **Mask variable** (bắt buộc để không lộ mật khẩu trong logs).
4. Nhấn **Save variables**.

---

## 5. Đường link Docker Hub Repository

- **Link Docker Hub**: `https://hub.docker.com/r/namnt2942003/payment-service`
  *(Thay thế `namnt2942003` bằng username Docker Hub của bạn).*
