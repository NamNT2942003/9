# BÀI TẬP 1: KHẮC PHỤC SỰ CỐ PIPELINE CI/CD CƠ BẢN (GITLAB CI)

## 1. Tình huống nghiệp vụ & Mã nguồn ban đầu
Dự án Microservices triển khai module **User Service** gặp sự cố trên GitLab CI/CD. Cấu hình ban đầu của file `.gitlab-ci.yml` do lập trình viên trước để lại như sau:

```yaml
stages:
  build_app

build_job:
  stage: build_app
  script:
    - ./gradlew clean build -x test
```

**Hiện tượng lỗi**: Pipeline liên tục báo lỗi `command not found` ngay từ bước khởi tạo, không thể build ứng dụng để giao cho khách hàng demo.

---

## 2. Phân tích nguyên nhân sự cố

Đoạn mã cấu hình trên gặp phải **2 lỗi/thiếu sót cốt lõi** khiến pipeline thất bại:

### ❌ Lỗi 1: Sai cú pháp khai báo mảng `stages` trong YAML
- **Nguyên nhân**:
  - Trong cú pháp của GitLab CI, keyword `stages` nhận giá trị là một **mảng/danh sách (array/sequence)** các chuỗi để định nghĩa các giai đoạn thực thi trong pipeline.
  - Theo chuẩn cú pháp YAML, các phần tử của một danh sách (list) bắt buộc phải có tiền tố là dấu gạch ngang theo sau bởi khoảng trắng (`- `).
  - Khai báo ban đầu:
    ```yaml
    stages:
      build_app
    ```
    hoàn toàn thiếu dấu `- `. Điều này khiến trình phân tích YAML hiểu `build_app` là một giá trị vô hướng (scalar string) hoặc cú pháp mapping không hợp lệ, vi phạm schema của GitLab CI (`jobs:stages config should be an array of strings`).
  - Hệ quả: Pipeline sẽ bị từ chối ngay từ khâu cú pháp (YAML syntax / schema validation error) và không thể khởi tạo runner.

### ❌ Lỗi 2: Thiếu định nghĩa Docker `image` chứa môi trường Java / Gradle
- **Nguyên nhân**:
  - GitLab Runner hoạt động chủ yếu dựa trên Docker Executor. Khi một job được kích hoạt mà file cấu hình không chỉ định từ khóa `image:`, runner sẽ sử dụng Docker image mặc định được cấu hình trên server (thường là `ruby:latest` do lịch sử phát triển của GitLab, hoặc các image Linux tối giản như `alpine:latest` hay `ubuntu:latest`).
  - Những Docker image mặc định này **không hề cài đặt sẵn** môi trường Java Runtime Environment (JRE), Java Development Kit (JDK) hay Gradle.
  - Lệnh script được gọi là:
    ```bash
    ./gradlew clean build -x test
    ```
    Gradle Wrapper (`gradlew`) bản chất là một shell script điều hướng việc tải và khởi chạy Gradle thông qua câu lệnh `java`. Khi không có JDK trong biến môi trường `$PATH`:
    - Shell sẽ báo lỗi: `java: command not found` hoặc `ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.`
    - Thậm chí nếu runner dùng môi trường không có bash/sh tương thích, nó sẽ báo `./gradlew: command not found`.
  - Đây chính là lý do trực tiếp gây ra lỗi `command not found` ngay từ bước khởi tạo như tình huống mô tả.

### ⚠️ Điểm cải tiến thực tế (Best Practices)
1. **Quyền thực thi của `./gradlew` (`chmod +x gradlew`)**:
   - Khi commit từ môi trường Windows lên Git, bit thực thi (`executable bit`) của file script có thể bị mất. Khi sang môi trường Linux Runner, việc chạy `./gradlew` có thể gặp lỗi `Permission denied`. Do đó, cần bổ sung `before_script: chmod +x ./gradlew`.
2. **Lưu trữ Artifacts (`artifacts`)**:
   - Tình huống nghiệp vụ yêu cầu cung cấp bản build gấp để demo cho khách hàng. Nếu chỉ chạy build mà không khai báo `artifacts`, file JAR sinh ra tại `build/libs/` sẽ bị xóa bỏ ngay khi Docker container của runner kết thúc. Khai báo `artifacts` giúp lưu giữ file `.jar` để tải về kiểm thử.

---

## 3. Nội dung file `.gitlab-ci.yml` chuẩn xác sau khi sửa

```yaml
# ========================================================
# GitLab CI/CD Pipeline - User Service
# Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản
# ========================================================

# 1. Định nghĩa Docker image chứa môi trường Java JDK 17 và Gradle
# Khắc phục lỗi thiếu JDK/Gradle dẫn đến "command not found"
image: gradle:8.5-jdk17

# 2. Định nghĩa danh sách các stages đúng chuẩn cú pháp mảng YAML (có dấu -)
stages:
  - build_app

# 3. Cấp quyền thực thi cho Gradle Wrapper trước khi chạy các tác vụ build
before_script:
  - chmod +x ./gradlew

# 4. Job build ứng dụng và đóng gói artifact
build_job:
  stage: build_app
  script:
    - ./gradlew clean build -x test
  artifacts:
    name: "user-service-build-$CI_COMMIT_SHORT_SHA"
    paths:
      - build/libs/*.jar
    expire_in: 1 week
```

---

## 4. Tóm tắt các thay đổi chính

| Thành phần | Cấu hình cũ (Lỗi) | Cấu hình mới (Đã sửa) | Mục đích |
| :--- | :--- | :--- | :--- |
| **Docker Image** | *(Không có)* | `image: gradle:8.5-jdk17` | Cung cấp môi trường JDK 17 & Gradle runtime, khắc phục lỗi `command not found`. |
| **Khai báo `stages`** | `stages:`<br>&nbsp;&nbsp;`build_app` | `stages:`<br>&nbsp;&nbsp;`- build_app` | Đúng chuẩn mảng YAML, vượt qua kiểm tra cú pháp của GitLab CI. |
| **Quyền thực thi** | *(Không có)* | `before_script:`<br>&nbsp;&nbsp;`- chmod +x ./gradlew` | Tránh lỗi `Permission denied` khi chạy script wrapper trên Linux runner. |
| **Lưu trữ kết quả** | *(Không có)* | `artifacts:`<br>&nbsp;&nbsp;`paths: [build/libs/*.jar]` | Lưu giữ file JAR để khách hàng có thể tải về demo ngay lập tức. |
