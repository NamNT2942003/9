# Báo Cáo Tổng Hợp Thực Hành DevOps & CI/CD

- **Repository**: [NamNT2942003/9](https://github.com/NamNT2942003/9)
- **Tác giả**: NamNTHE176286

---

## 📑 Danh mục bài tập

1. [Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản (GitLab CI)](#-bài-tập-1-khắc-phục-sự-cố-pipeline-cicd-cơ-bản-gitlab-ci)
2. [Bài tập 2: Container hóa ứng dụng Spring Boot Microservices (Dockerfile)](#-bài-tập-2-container-hóa-ứng-dụng-spring-boot-microservices-dockerfile)

---

## 🚀 Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản (GitLab CI)

> Chi tiết xem tại file: [BAITAP1_GIAI_THICH.md](./BAITAP1_GIAI_THICH.md) và cấu hình [`.gitlab-ci.yml`](./.gitlab-ci.yml)

### 1. Phân tích 2 lỗi cốt lõi trong file `.gitlab-ci.yml` ban đầu
- **Lỗi 1 (Sai cú pháp mảng YAML trong `stages`)**: Khai báo `stages:` thiếu dấu gạch đầu dòng `- ` trước `build_app`. Trong GitLab CI schema, `stages` bắt buộc phải là mảng chuỗi (`array of strings`).
- **Lỗi 2 (Thiếu Docker image chứa Java/Gradle)**: Runner mặc định không cài đặt sẵn JDK hay Gradle. Khi thực thi `./gradlew clean build -x test`, hệ thống báo lỗi `command not found` vì thiếu `java` trong `$PATH`.
- **Cải tiến**: Thêm `before_script: chmod +x ./gradlew` và định nghĩa `artifacts` để lưu trữ file JAR phục vụ demo.

### 2. Cấu hình `.gitlab-ci.yml` hoàn chỉnh
```yaml
image: gradle:8.5-jdk17

stages:
  - build_app

before_script:
  - chmod +x ./gradlew

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

## 🐳 Bài tập 2: Container hóa ứng dụng Spring Boot Microservices (Dockerfile)

> Chi tiết xem tại file: [BAITAP2_GIAI_THICH.md](./BAITAP2_GIAI_THICH.md) và file [`Dockerfile`](./Dockerfile)

### 1. Nội dung file `Dockerfile` chuẩn xác

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

### 2. Bảng phân tích chi tiết các keywords

| Keyword | Cú pháp áp dụng | Vai trò kỹ thuật |
| :--- | :--- | :--- |
| **`FROM`** | `FROM eclipse-temurin:17-jre-alpine` | Sử dụng JRE 17 trên nền tảng Alpine Linux siêu nhẹ (~150MB), tối ưu kích thước và bảo mật so với JDK đầy đủ. |
| **`WORKDIR`** | `WORKDIR /app` | Thiết lập không gian làm việc cô lập trong container, mọi lệnh sau đó chạy tương đối tại `/app`. |
| **`COPY`** | `COPY build/libs/payment-service-1.0.0.jar app.jar` | Đưa file JAR sau build vào container và chuẩn hóa tên thành `app.jar`. |
| **`EXPOSE`** | `EXPOSE 8080` | Khai báo cổng 8080 mà service Spring Boot lắng nghe, phục vụ kết nối mạng giữa các microservices. |
| **`ENTRYPOINT`** | `ENTRYPOINT ["java", "-jar", "app.jar"]` | Định dạng Exec Form giúp Java chạy với PID 1, hỗ trợ bắt tín hiệu Graceful Shutdown (`SIGTERM`). |
