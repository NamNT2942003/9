# Báo Cáo Tổng Hợp Thực Hành DevOps & CI/CD

- **Repository**: [NamNT2942003/9](https://github.com/NamNT2942003/9)
- **Tác giả**: NamNTHE176286

---

## 📑 Danh mục bài tập

1. [Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản (GitLab CI)](#-bài-tập-1-khắc-phục-sự-cố-pipeline-cicd-cơ-bản-gitlab-ci)
2. [Bài tập 2: Container hóa ứng dụng Spring Boot Microservices (Dockerfile)](#-bài-tập-2-container-hóa-ứng-dụng-spring-boot-microservices-dockerfile)
3. [Bài tập 3: Xây dựng Pipeline CI/CD kết nối PostgreSQL (GitLab CI Services)](#-bài-tập-3-xây-dựng-pipeline-cicd-kết-nối-postgresql-gitlab-ci-services)

---

## 🚀 Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản (GitLab CI)

> Chi tiết xem tại file: [BAITAP1_GIAI_THICH.md](./BAITAP1_GIAI_THICH.md)

- **Nguyên nhân lỗi ban đầu**:
  1. Sai cú pháp mảng YAML: Khai báo `stages: build_app` thiếu dấu gạch đầu dòng `- ` (phải là `- build_app`).
  2. Thiếu Docker image: Runner mặc định không có môi trường Java/Gradle dẫn tới lỗi `command not found` khi chạy `./gradlew`.
- **Khắc phục**: Khai báo `image: gradle:8.5-jdk17`, sửa cú pháp `- build_app`, thêm `chmod +x ./gradlew` và cấu hình lưu trữ `artifacts`.

---

## 🐳 Bài tập 2: Container hóa ứng dụng Spring Boot Microservices (Dockerfile)

> Chi tiết xem tại file: [BAITAP2_GIAI_THICH.md](./BAITAP2_GIAI_THICH.md) và file [`Dockerfile`](./Dockerfile)

### Nội dung file `Dockerfile`:
```dockerfile
# 1. Chọn base image chứa JRE 17 gọn nhẹ
FROM eclipse-temurin:17-jre-alpine

# 2. Tạo thư mục làm việc trong container
WORKDIR /app

# 3. Copy file jar từ thư mục build của Gradle vào container
COPY build/libs/payment-service-1.0.0.jar app.jar

# 4. Mở port 8080 để giao tiếp với các microservices khác
EXPOSE 8080

# 5. Lệnh khởi chạy ứng dụng Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 🐘 Bài tập 3: Xây dựng Pipeline CI/CD kết nối PostgreSQL (GitLab CI Services)

> Chi tiết xem tại file: [BAITAP3_GIAI_THICH.md](./BAITAP3_GIAI_THICH.md) và file cấu hình [`.gitlab-ci.yml`](./.gitlab-ci.yml)

### 1. Cấu hình `.gitlab-ci.yml` chuẩn xác
```yaml
# Sử dụng image Gradle tích hợp sẵn JDK 17
image: gradle:7.6-jdk17

# Định nghĩa 2 stages chạy tuần tự: test trước, build sau
stages:
  - test
  - build

before_script:
  - chmod +x ./gradlew

# Stage 1: Chạy Unit & Integration Test với PostgreSQL Service
test_job:
  stage: test
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
  script:
    - ./gradlew test

# Stage 2: Đóng gói ứng dụng thành file JAR và lưu trữ artifact
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

### 2. Điểm cốt lõi kỹ thuật
- **Tuần tự**: Stage `test` chạy trước, nếu pass mới chuyển sang `build` (ngăn chặn build mã nguồn có lỗi logic).
- **`services`**: Khởi chạy container `postgres:14-alpine` song song, cung cấp Database tạm thời cho Integration Test, truy cập qua DNS hostname `postgres`.
- **`artifacts`**: Lưu giữ file JAR trong `build/libs/*.jar` với hạn sử dụng `expire_in: 1 day`.
