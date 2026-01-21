# 1. Chọn Base Image (Môi trường Java 21)
FROM eclipse-temurin:21-jdk

# 2. Tạo thư mục làm việc trong Container
WORKDIR /app

# 3. Copy file .jar từ máy tính vào trong Container
# Lưu ý: Bạn phải chạy mvn clean package trước thì mới có file trong target/
COPY target/*.jar app.jar

# 4. Tạo thư mục uploads trong container
RUN mkdir -p /app/uploads

# 5. Mở cổng 8080 (Để documentation, thực tế Docker Compose sẽ lo việc map port)
EXPOSE 8080

# 6. Lệnh chạy App khi Container khởi động
ENTRYPOINT ["java", "-jar", "app.jar"]
