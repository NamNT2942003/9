# BÀI TẬP 2: CONTAINER HÓA ỨNG DỤNG SPRING BOOT MICROSERVICES

## 1. Tình huống nghiệp vụ & Mục tiêu
- **Dịch vụ**: Payment Service (Microservice thanh toán).
- **Artifact đầu ra**: File `payment-service-1.0.0.jar` tại thư mục `build/libs/` (được build bằng Gradle).
- **Yêu cầu**: Viết `Dockerfile` chuẩn để đóng gói microservice này thành một Docker image gọn nhẹ, bảo mật và sẵn sàng triển khai trên server.

---

## 2. File `Dockerfile` hoàn chỉnh

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

## 3. Phân tích chi tiết từng chỉ thị (Keywords)

| STT | Keyword | Cú pháp hoàn chỉnh | Vai trò & Ý nghĩa kỹ thuật |
| :--- | :--- | :--- | :--- |
| **1** | **`FROM`** | `FROM eclipse-temurin:17-jre-alpine` | - Xác định base image nền tảng.<br>- Ứng dụng đã được biên dịch thành file JAR nên chỉ cần **JRE** (Java Runtime Environment) để chạy, không cần JDK đầy đủ.<br>- Phân phối **Alpine Linux** siêu nhẹ giúp giảm kích thước image từ ~500MB xuống còn ~150MB, tăng tốc độ pull/push image và giảm diện tích tấn công (attack surface) về bảo mật. |
| **2** | **`WORKDIR`** | `WORKDIR /app` | - Thiết lập thư mục làm việc gốc bên trong container.<br>- Nếu `/app` chưa tồn tại, Docker sẽ tự động tạo.<br>- Các chỉ thị tiếp theo (`COPY`, `ENTRYPOINT`) sẽ thực thi tương đối tại thư mục này, tránh lưu file rải rác ở thư mục root (`/`). |
| **3** | **`COPY`** | `COPY build/libs/payment-service-1.0.0.jar app.jar` | - Sao chép file `.jar` đã build từ máy host vào thư mục `/app` trong container.<br>- Đổi tên thành `app.jar` để chuẩn hóa đường dẫn khởi chạy, không phụ thuộc vào version cụ thể trong lệnh chạy sau này. |
| **4** | **`EXPOSE`** | `EXPOSE 8080` | - Khai báo cổng mạng (port 8080 mặc định của Spring Boot) mà ứng dụng sẽ lắng nghe.<br>- Đóng vai trò cấu hình tài liệu hóa (metadata) cho Docker engine và các kỹ sư DevOps, giúp dễ dàng map port khi chạy `docker run -p 8080:8080` hoặc cấu hình Kubernetes Service / Docker Compose. |
| **5** | **`ENTRYPOINT`** | `ENTRYPOINT ["java", "-jar", "app.jar"]` | - Định nghĩa lệnh cố định thực thi khi container được khởi động.<br>- Sử dụng định dạng **Exec Form** (dạng mảng JSON `["executable", "param1", ...]`) giúp tiến trình Java chạy trực tiếp ở **PID 1**, nhận đúng các tín hiệu `SIGTERM`, `SIGINT` từ hệ thống để thực hiện **Graceful Shutdown** mượt mà khi scale hoặc restart container. |

---

## 4. Hướng dẫn Build & Run Docker Container

### Bước 1: Build file JAR từ Gradle
```bash
./gradlew clean build -x test
```

### Bước 2: Build Docker Image
```bash
docker build -t payment-service:1.0.0 .
```

### Bước 3: Khởi chạy Container
```bash
docker run -d -p 8080:8080 --name payment-service-app payment-service:1.0.0
```

### Bước 4: Kiểm tra trạng thái & Log
```bash
docker ps
docker logs -f payment-service-app
```
