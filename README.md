# Báo Cáo Bài Tập 1: Khắc Phục Sự Cố Pipeline CI/CD Cơ Bản (GitLab CI)

## 📌 Thông tin bài tập
- **Repository**: [NamNT2942003/9](https://github.com/NamNT2942003/9)
- **Module**: `User Service`
- **Mục tiêu**:
  - Khắc phục sự cố pipeline GitLab CI/CD của module `User Service`.
  - Phân tích và chỉ rõ nguyên nhân gây ra lỗi `command not found` và lỗi cú pháp.
  - Viết lại cấu hình `.gitlab-ci.yml` chuẩn xác, tối ưu và đảm bảo đóng gói bàn giao demo.

---

## 1. Tình huống nghiệp vụ & Đoạn cấu hình bị lỗi

Lập trình viên trước đã tạo file `.gitlab-ci.yml` như sau:

```yaml
stages:
  build_app

build_job:
  stage: build_app
  script:
    - ./gradlew clean build -x test
```

Pipeline liên tục bị lỗi ngay từ bước khởi tạo với thông báo `command not found`.

---

## 2. Phân tích nguyên nhân lỗi

Cấu hình trên có **2 lỗi/thiếu sót cốt lõi**:

### ❌ Lỗi 1: Sai cú pháp khai báo mảng `stages` trong YAML
- **Hiện trạng**:
  ```yaml
  stages:
    build_app
  ```
- **Nguyên nhân**:
  - Trong GitLab CI, `stages` là từ khóa dùng để định danh danh sách các giai đoạn theo thứ tự thực hiện. Giá trị của `stages` **bắt buộc phải là một mảng chuỗi (array/sequence of strings)**.
  - Quy chuẩn cú pháp YAML quy định các phần tử trong danh sách phải bắt đầu bằng ký tự gạch đầu dòng kèm khoảng trắng (`- `).
  - Khai báo thiếu dấu `- ` khiến YAML parser nhận diện `build_app` là kiểu dữ liệu chuỗi/vô hướng (scalar) thay vì danh sách, vi phạm schema xác thực cấu hình của GitLab CI (`jobs:stages config should be an array of strings`), dẫn đến pipeline bị lỗi cú pháp ngay khi nạp file cấu hình.
- **Cách khắc phục**: Thêm dấu `- ` trước tên stage:
  ```yaml
  stages:
    - build_app
  ```

### ❌ Lỗi 2: Thiếu định nghĩa Docker `image` chứa môi trường Java & Gradle
- **Hiện trạng**: File cấu hình hoàn toàn không khai báo từ khóa `image:`.
- **Nguyên nhân**:
  - GitLab Runner (với Docker executor) khi không tìm thấy chỉ thị `image:` sẽ tự động nạp image mặc định của hệ thống (thường là `ruby:latest` hoặc các base image Linux tối giản).
  - Các Docker image mặc định này không cài đặt sẵn môi trường Java (JDK/JRE) hay Gradle.
  - Gradle Wrapper (`./gradlew`) là script khởi động yêu cầu lệnh `java` có sẵn trong biến môi trường hệ thống (`$PATH`). Khi runner gọi `./gradlew clean build -x test`:
    - Shell không tìm thấy runtime `java`, dẫn đến lỗi `ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.` hoặc `command not found`.
- **Cách khắc phục**: Khai báo image chính thức chứa môi trường Gradle và JDK 17:
  ```yaml
  image: gradle:8.5-jdk17
  ```

### 💡 Điểm bổ sung tối ưu (Best Practices):
1. **Cấp quyền thực thi (`chmod +x ./gradlew`)**: Khi mã nguồn được quản lý trên môi trường Windows hoặc Git chưa lưu thuộc tính file execute bit, runner Linux sẽ báo lỗi `Permission denied`. Việc bổ sung `before_script: chmod +x ./gradlew` đảm bảo script luôn có quyền thực thi.
2. **Lưu trữ Artifacts (`artifacts`)**: Dự án cần bản build để demo gấp cho khách hàng. Thêm cấu hình `artifacts` giúp lưu giữ file `.jar` sau khi build xong trong thư mục `build/libs/`.

---

## 3. Nội dung file `.gitlab-ci.yml` hoàn chỉnh

```yaml
# ========================================================
# GitLab CI/CD Pipeline - User Service
# Bài tập 1: Khắc phục sự cố Pipeline CI/CD cơ bản
# ========================================================

# 1. Khai báo Docker image chứa JDK 17 & Gradle
image: gradle:8.5-jdk17

# 2. Sửa cú pháp mảng stages chuẩn YAML
stages:
  - build_app

# 3. Đảm bảo quyền thực thi cho Gradle wrapper
before_script:
  - chmod +x ./gradlew

# 4. Job thực hiện build ứng dụng và lưu trữ artifact demo
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

## 4. Bảng tổng hợp đối chiếu

| Tiêu chí | File gốc (Lỗi) | File sửa đổi (Chuẩn) | Ý nghĩa xử lý |
| :--- | :--- | :--- | :--- |
| **Môi trường chạy (`image`)** | Không có | `image: gradle:8.5-jdk17` | Khắc phục lỗi thiếu JDK/Gradle (`command not found`). |
| **Cú pháp mảng (`stages`)** | `stages:`<br>&nbsp;&nbsp;`build_app` | `stages:`<br>&nbsp;&nbsp;`- build_app` | Khắc phục lỗi cú pháp YAML và schema validation của GitLab CI. |
| **Quyền file (`before_script`)**| Không có | `- chmod +x ./gradlew` | Tránh lỗi `Permission denied` trên môi trường Linux container. |
| **Bàn giao kết quả (`artifacts`)**| Không có | `paths: [build/libs/*.jar]` | Lưu trữ file build JAR để bàn giao demo cho khách hàng. |
