# BÀI TẬP 5: TỐI ƯU HOÁ QUY TRÌNH CI/CD VỚI MULTI-STAGE BUILD BẰNG GRADLE

## 1. Tình huống nghiệp vụ & Đặt vấn đề
- **Service**: Notification Service (Microservice xử lý thông báo).
- **Vấn đề**: Docker image của service có kích thước lên đến **~850MB** dù mã nguồn thực tế chỉ vài chục KB.
- **Nguyên nhân cốt lõi**:
  - Dockerfile đang xây dựng theo mô hình **Single-stage (Fat Container)**: Copy toàn bộ source code vào một image có sẵn JDK + Gradle, chạy build bên trong rồi sử dụng luôn image đó để deploy.
  - Hậu quả: Image chứa toàn bộ trình biên dịch `javac`, công cụ đóng gói Gradle (~150MB), Gradle cache/wrapper, mã nguồn gốc (`src/`) cùng vô số gói tiện ích hệ điều hành không cần thiết cho quá trình chạy.
- **Mục tiêu**: Thiết kế Dockerfile theo mô hình **Multi-stage Build** để tách biệt môi trường Build (Compile) và môi trường Chạy (Runtime), giảm dung lượng xuống còn **150-200MB** và bảo vệ an toàn mã nguồn.

---

## 2. Bảng so sánh chuyên sâu: Single-stage Build vs Multi-stage Build

| Tiêu chí so sánh | Single-stage Build (Fat Container) | Multi-stage Build (Tối ưu) | Đánh giá & Lợi ích |
| :--- | :--- | :--- | :--- |
| **Cấu trúc Dockerfile** | Chỉ có 1 lệnh `FROM` duy nhất (ví dụ: `FROM gradle:7.6-jdk17`). Build và run trên cùng một image. | Sử dụng nhiều lệnh `FROM` (Stage 1: `AS builder`, Stage 2: `FROM ...-alpine`). Thừa kế artifact qua `COPY --from=builder`. | **Multi-stage** tách bạch rõ ràng trách nhiệm giữa khâu build và khâu chạy. |
| **Dung lượng Image dự kiến** | **~850MB - 1GB** *(Rất nặng)* | **~150MB - 180MB** *(Giảm > 75%)* | Giảm dung lượng vượt trội, tiết kiệm chi phí lưu trữ trên Registry và băng thông truyền tải. |
| **Bảo mật mã nguồn (Source Code)** | ❌ **Rất nguy hiểm**: Toàn bộ thư mục `src/`, file cấu hình, logic nghiệp vụ nằm trực tiếp trong image production. | ✅ **An toàn tuyệt đối**: Chỉ copy duy nhất file `.jar` thành phẩm sang image cuối; toàn bộ source code bị loại bỏ ở builder. | Ngăn chặn nguy cơ bị trích xuất hoặc lộ mã nguồn (Reverse Engineering) khi container bị truy cập trái phép. |
| **Công cụ bên trong Image (Tools)** | Chứa đầy đủ: JDK, compiler `javac`, `gradle`, build tools, shell utilities, git... | Chỉ chứa **JRE** (Java Runtime) tối giản và các thư viện cần thiết của Alpine Linux. | Loại bỏ các công cụ thừa giúp hacker không thể lợi dụng compiler để biên dịch/thực thi mã độc trong container. |
| **Diện tích tấn công (Attack Surface & CVEs)** | **Rất lớn**: Do chứa hàng trăm packages hệ điều hành và thư viện phát triển, số lượng lỗ hổng bảo mật (CVEs) tiềm ẩn rất cao. | **Cực nhỏ**: Nền tảng Alpine Linux tối giản chỉ giữ lại các package cốt lõi, giảm thiểu tối đa các cảnh báo bảo mật. | Nâng cao điểm số tuân thủ an toàn thông tin (Security Compliance / Trivy Scanner). |
| **Tốc độ Pull / Push / Deploy** | Chậm (mất nhiều thời gian kéo image nặng gần 1GB khi scale pods hoặc deploy server mới). | Rất nhanh (chỉ mất vài giây để kéo image ~150MB). | Tối ưu thời gian **CI/CD Pipeline** và thời gian khởi động Pods trong Kubernetes (HPA autoscaling). |

---

## 3. Nội dung file `Dockerfile` Multi-stage hoàn chỉnh

```dockerfile
# ========================================================
# Dockerfile Multi-stage Build cho Spring Boot Microservice
# Stage 1: Builder - Sử dụng Gradle và JDK để biên dịch mã nguồn
# Stage 2: Runner - Chỉ dùng JRE Alpine siêu nhẹ để chạy file .jar
# ========================================================

# --------------------------------------------------------
# Stage 1: Builder
# --------------------------------------------------------
FROM gradle:7.6-jdk17 AS builder

# Thiết lập thư mục làm việc trong container builder
WORKDIR /home/gradle/project

# Copy toàn bộ mã nguồn vào container builder
COPY . .

# Cấp quyền thực thi cho Gradle wrapper và chạy lệnh build đóng gói
RUN chmod +x ./gradlew && ./gradlew clean build -x test

# --------------------------------------------------------
# Stage 2: Runner (Production Image)
# --------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine

# Thiết lập thư mục chạy ứng dụng
WORKDIR /app

# Copy MỖI file .jar từ đường dẫn /home/gradle/project/build/libs/ của stage builder sang
COPY --from=builder /home/gradle/project/build/libs/*.jar app.jar

# Mở port 8080 để giao tiếp với các microservices khác
EXPOSE 8080

# Lệnh khởi chạy ứng dụng Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 4. Phân tích luồng hoạt động của Multi-stage Build

```
[Máy tính / CI Runner]
        │
        ▼ (COPY . .)
┌────────────────────────────────────────────────────────┐
│ STAGE 1: gradle:7.6-jdk17 (Builder - Dung lượng ~800MB)│
│  - Chứa JDK 17, Gradle 7.6, mã nguồn src/, tests...   │
│  - Chạy lệnh: ./gradlew clean build -x test           │
│  - Sinh ra: /home/gradle/project/build/libs/*.jar      │
└────────────────────────────────────────────────────────┘
        │
        │ COPY --from=builder /.../*.jar app.jar (Chỉ lấy duy nhất file JAR)
        ▼
┌────────────────────────────────────────────────────────┐
│ STAGE 2: eclipse-temurin:17-jre-alpine (~150MB)        │
│  - Chỉ chứa JRE 17 + Alpine Linux tối giản            │
│  - Chứa đúng 1 file: /app/app.jar                     │
│  - KHÔNG có JDK, KHÔNG có Gradle, KHÔNG có source code │
│  - ENTRYPOINT ["java", "-jar", "app.jar"]             │
└────────────────────────────────────────────────────────┘
        │
        ▼
[DOCKER IMAGE CUỐI CÙNG DÙNG ĐỂ DEPLOY: ~160MB]
```

---

## 5. Kết luận & Khuyến nghị thực tiễn

1. **Về mặt kích thước**: Multi-stage build loại bỏ hoàn toàn các layer trung gian của quá trình biên dịch, nén kích thước Docker image của Notification Service từ **850MB** xuống còn **~160MB** (giảm tới ~81%).
2. **Về mặt an ninh**: Môi trường production không bao giờ được phép chứa mã nguồn dạng raw text (`.java`, `.properties`) hay compiler (`javac`). Multi-stage build là tiêu chuẩn bắt buộc (de-facto standard) trong quy trình đóng gói microservice hiện đại.
