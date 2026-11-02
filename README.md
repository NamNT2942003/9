# Báo cáo Bài 3: Thiết lập luồng CI tuần tự xử lý Job Isolation

## 1. Bối cảnh & Mục tiêu
- **Dự án**: QuickBite Microservices Platform.
- **Service**: `payment-service`.
- **Mục tiêu**: 
  - Thiết lập luồng CI tuần tự giữa 2 job: **Job 1 (Test)** -> **Job 2 (Build)** bằng từ khóa `needs`.
  - Hiểu và giải quyết bài toán **Job Isolation** trong GitHub Actions (tính cô lập giữa các runner).
  - Đảm bảo Job Build chỉ chạy khi Job Test vượt qua, sau đó upload file JAR làm artifact.

---

## 2. Kiến thức cốt lõi & Cơ chế hoạt động

### 🔗 1. Luồng tuần tự với từ khóa `needs`
- **Mặc định trong GitHub Actions**: Tất cả các job được khai báo dưới `jobs:` sẽ **chạy song song (parallel)** nhằm tối ưu thời gian.
- **Yêu cầu bài toán**: `payment-service` yêu cầu không được build nếu Unit Test chưa pass.
- **Giải pháp**: Khai báo `needs: [test]` trong job `build`.
  - Khi đó, GitHub Actions dựng dependency graph: Job `build` sẽ đợi Job `test` hoàn thành với kết quả `success`.
  - Nếu Job `test` thất bại (`failed`), Job `build` sẽ lập tức bị hủy bỏ (`skipped`) và pipeline dừng lại, ngăn chặn việc đóng gói mã nguồn lỗi.

### 📦 2. Cơ chế Job Isolation (Tính cô lập giữa các Job)
- **Bản chất**: Mỗi job trong GitHub Actions được khởi chạy trên một máy ảo độc lập hoàn toàn (`ubuntu-latest` runner mới tinh).
- **Hệ quả**: Runner của Job 2 **không tự động kế thừa** bất kỳ dữ liệu nào từ Job 1 (không có mã nguồn, không có cấu hình môi trường, không có dependencies đã tải trước đó).
- **Cách xử lý chuẩn xác**:
  - Ở Job `build`, bắt buộc phải khai báo lại:
    1. `actions/checkout@v4`: Để clone lại mã nguồn về runner của Job 2.
    2. `actions/setup-java@v4`: Để cấu hình môi trường Java 21 trên runner của Job 2.
    3. `chmod +x ./gradlew`: Cấp quyền thực thi trước khi gọi `./gradlew bootJar`.

---

## 3. Nội dung file Workflow hoàn chỉnh (`.github/workflows/ci.yml`)

```yaml
name: Payment Service CI

on:
  push:
    branches:
      - main

jobs:
  test:
    name: Run Unit Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Java JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Run Unit Tests
        run: |
          chmod +x ./gradlew
          ./gradlew test

  build:
    name: Build & Package Artifact
    needs: [test]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code (Job Isolation Requirement)
        uses: actions/checkout@v4

      - name: Setup Java JDK 21 (Job Isolation Requirement)
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'

      - name: Build JAR with Gradle
        run: |
          chmod +x ./gradlew
          ./gradlew bootJar

      - name: Upload Build Artifact
        uses: actions/upload-artifact@v4
        with:
          name: payment-service-artifact
          path: build/libs/*.jar
          retention-days: 3
```

---

## 4. Hướng dẫn Push lên GitHub & Nộp bài

1. **Tạo repository mới**:
   - Truy cập: https://github.com/new
   - Tên Repository: `9` (hoặc `quickbite-payment-service`)
   - Chọn **Public** -> Nhấn **Create repository**.

2. **Push mã nguồn từ thư mục `C:\Devop\9`**:
   ```bash
   cd C:\Devop\9
   git remote add origin https://github.com/NamNT2942003/9.git
   git push -u origin main
   ```

3. **Kiểm tra kết quả trên GitHub**:
   - Vào tab **Actions**: `https://github.com/NamNT2942003/9/actions`
   - Bấm vào lần chạy mới nhất.
   - Sơ đồ trực quan (Workflow Graph) sẽ thể hiện rõ mũi tên liên kết tuần tự:
     ```text
     [ Run Unit Tests ] ──> [ Build & Package Artifact ]
     ```
   - Cả 2 job đều tích xanh và có mục **Artifacts** chứa `payment-service-artifact`.
4. Copy link run hoặc link repository để dán vào bài nộp Portal.
