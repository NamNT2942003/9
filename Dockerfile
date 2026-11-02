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
