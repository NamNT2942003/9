# Báo Cáo Tổng Hợp Thực Hành DevOps & CI/CD

- **Repository**: [NamNT2942003/9](https://github.com/NamNT2942003/9)
- **Tác giả**: NamNTHE176286
- **Docker Hub**: [https://hub.docker.com/r/namnt2942003/payment-service](https://hub.docker.com/r/namnt2942003/payment-service)

---

## 📑 Danh mục bài tập

1. [Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản (GitLab CI)](#-bài-tập-1-khắc-phục-sự-cố-pipeline-cicd-cơ-bản-gitlab-ci)
2. [Bài tập 2: Container hóa ứng dụng Spring Boot Microservices (Dockerfile)](#-bài-tập-2-container-hóa-ứng-dụng-spring-boot-microservices-dockerfile)
3. [Bài tập 3: Xây dựng Pipeline CI/CD kết nối PostgreSQL (GitLab CI Services)](#-bài-tập-3-xây-dựng-pipeline-cicd-kết-nối-postgresql-gitlab-ci-services)
4. [Bài tập 4: Đẩy Docker Image lên Docker Hub thông qua GitLab CI (DinD)](#-bài-tập-4-đẩy-docker-image-lên-docker-hub-thông-qua-gitlab-ci-dind)
5. [Bài tập 5: Tối ưu hoá quy trình CI/CD với Multi-stage Build bằng Gradle](#-bài-tập-5-tối-ưu-hoá-quy-trình-cicd-với-multi-stage-build-bằng-gradle)

---

## 🚀 Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản (GitLab CI)

> Chi tiết xem tại file: [BAITAP1_GIAI_THICH.md](./BAITAP1_GIAI_THICH.md)

- **Nguyên nhân lỗi ban đầu**:
  1. Sai cú pháp mảng YAML: Khai báo `stages: build_app` thiếu dấu gạch đầu dòng `- ` (phải là `- build_app`).
  2. Thiếu Docker image: Runner mặc định không có môi trường Java/Gradle dẫn tới lỗi `command not found` khi chạy `./gradlew`.
- **Khắc phục**: Khai báo `image: gradle:8.5-jdk17`, sửa cú pháp `- build_app`, thêm `chmod +x ./gradlew` và cấu hình lưu trữ `artifacts`.

---

## 🐳 Bài tập 2: Container hóa ứng dụng Spring Boot Microservices (Dockerfile)

> Chi tiết xem tại file: [BAITAP2_GIAI_THICH.md](./BAITAP2_GIAI_THICH.md)

- Điền các keyword chuẩn của Docker: `FROM`, `WORKDIR`, `COPY`, `EXPOSE`, `ENTRYPOINT`.
- Sử dụng base image `eclipse-temurin:17-jre-alpine` để tối ưu kích thước ban đầu.

---

## 🐘 Bài tập 3: Xây dựng Pipeline CI/CD kết nối PostgreSQL (GitLab CI Services)

> Chi tiết xem tại file: [BAITAP3_GIAI_THICH.md](./BAITAP3_GIAI_THICH.md)

- **Tuần tự**: Stage `test` chạy trước, nếu pass mới chuyển sang `build` (ngăn chặn build mã nguồn có lỗi logic).
- **`services`**: Khởi chạy container `postgres:14-alpine` song song, cung cấp Database tạm thời cho Integration Test, truy cập qua DNS hostname `postgres`.
- **`artifacts`**: Lưu giữ file JAR trong `build/libs/*.jar` với hạn sử dụng `expire_in: 1 day`.

---

## 🚢 Bài tập 4: Đẩy Docker Image lên Docker Hub thông qua GitLab CI (DinD)

> Chi tiết xem tại file: [BAITAP4_GIAI_THICH.md](./BAITAP4_GIAI_THICH.md) và file cấu hình [`.gitlab-ci.yml`](./.gitlab-ci.yml)

- Cấu hình 3 stages: `test` ➔ `build` ➔ `dockerize`.
- Sử dụng **Docker-in-Docker (DinD)** với `image: docker:24.0.5` và `services: - docker:24.0.5-dind`.
- Bảo mật thông tin đăng nhập qua **CI/CD Variables** (`DOCKER_USERNAME`, `DOCKER_PASSWORD`) với tính năng **Mask variable**.
- Gắn đồng thời tag commit `$CI_COMMIT_SHORT_SHA` và `latest`.

---

## ⚡ Bài tập 5: Tối ưu hoá quy trình CI/CD với Multi-stage Build bằng Gradle

> Chi tiết xem tại file: [BAITAP5_GIAI_THICH.md](./BAITAP5_GIAI_THICH.md) và file [`Dockerfile`](./Dockerfile)

### 1. Bảng so sánh Single-stage Build vs Multi-stage Build

| Tiêu chí | Single-stage Build (Fat Container) | Multi-stage Build (Tối ưu) |
| :--- | :--- | :--- |
| **Dung lượng Image** | **~850MB - 1GB** | **~150MB - 180MB** (Giảm > 75%) |
| **Bảo mật Source Code** | ❌ Lộ toàn bộ mã nguồn trong thư mục `src/` | ✅ Tuyệt đối không chứa source code |
| **Môi trường Runtime** | Chứa cả compiler `javac`, `gradle`, build tools | Chỉ chứa `JRE 17` và thư viện Alpine tối giản |
| **Attack Surface (CVEs)** | Rất lớn, nhiều lỗ hổng từ các package thừa | Cực nhỏ, giảm thiểu tối đa các cảnh báo bảo mật |
| **Tốc độ Pull/Deploy** | Chậm, tốn nhiều băng thông mạng | Nhanh chóng, tiết kiệm tài nguyên hệ thống |

### 2. Cấu trúc `Dockerfile` Multi-stage hoàn chỉnh
```dockerfile
# Stage 1: Builder
FROM gradle:7.6-jdk17 AS builder
WORKDIR /home/gradle/project
COPY . .
RUN chmod +x ./gradlew && ./gradlew clean build -x test

# Stage 2: Runner
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /home/gradle/project/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```
