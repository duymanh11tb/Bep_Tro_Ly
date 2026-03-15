# Hướng dẫn Quy trình Git & Triển khai VPS (Dành cho Team)

Tài liệu này giúp thống nhất cách quản lý mã nguồn và triển khai dự án **Bếp Trợ Lý** giữa các thành viên.

---

## 1. Quy trình làm việc với Git (Git Workflow)

Để tránh xung đột code (conflict) và quản lý tính năng chuyên nghiệp, chúng ta thống nhất dùng mô hình **Feature Branching**.

### Quy tắc đặt tên Nhánh (Branch)

- `main`: Chứa code stable chạy trên Production. Tuyệt đối không code trực tiếp vào đây.
- `develop`: Nhánh chính để team gộp code. Tất cả các tính năng mới sau khi xong sẽ được gộp vào đây.
- `feature/[tên-tính-năng]`: Nhánh riêng để mỗi người làm tính năng (VD: `feature/auth-service`, `feature/recipe-ui`).
- `bugfix/[vấn-đề]`: Nhánh sửa lỗi nhanh.

### Các bước đẩy code (Push)

1. **Trước khi bắt đầu code:** Luôn cập nhật code mới nhất từ `develop`.
   ```bash
   git checkout develop
   git pull origin develop
   ```
2. **Tạo nhánh mới để làm việc:**
   ```bash
   git checkout -b feature/ten-cua-ban
   ```
3. **Lưu thay đổi (Commit):** Viết thông điệp rõ ràng (theo chuẩn Conventional Commits càng tốt).
   - `feat: thêm chức năng đăng nhập`
   - `fix: sửa lỗi gọi API Gemini`
   ```bash
   git add .
   git commit -m "feat: mo ta ngan gon"
   ```
4. **Đẩy code lên Github:**
   ```bash
   git push origin feature/ten-cua-ban
   ```
5. **Tạo Pull Request (PR):** Lên Github tạo PR từ nhánh của bạn vào nhánh `develop`. Team sẽ review và merge.

---

## 2. Quản lý cấu hình & Bảo mật

Dự án có các file nhạy cảm như `.env`, `appsettings.json`, `appsettings.Development.json`.

- **QUAN TRỌNG:** Các file này đã bị chặn bởi `.gitignore`. **KHÔNG** bao giờ đẩy các file này lên Github vì sẽ bị lộ mật khẩu DB và API Key.
- Khi một thành viên thêm biến môi trường mới vào file `.env`, cần thông báo cho cả nhóm để mọi người cùng cập nhật thủ công vào file `.env` trên máy của họ.

---

## 3. Triển khai lên VPS (Deployment)

Dự án sử dụng **Docker Compose** để chạy cả Database (MySQL) và Backend (.NET).

### Các bước triển khai (Trên VPS)

1. **Kết nối vào VPS:**
   ```bash -> Chạy powershell
   ssh root@103.77.173.6
   pass : trong box zalo
   ```
2. **Di chuyển vào thư mục dự án trên VPS.**
   ```bash
   cd /root/bep-tro-ly
   ```
3. **Cập nhật code mới nhất:**
   ```bash
   git checkout develop
   git pull origin dev
   ```
4. **Khởi chạy bằng Docker:**
   ```bash
   # Build lại image và chạy ngầm (-d)
   docker compose up -d --build
   ```

---

## 4. Bảo mật & Truy cập Database

Để bảo mật, cổng Database (3306) đã được **đóng** (không expose ra ngoài) trong file `docker-compose.yml` để tránh hacker tấn công trực tiếp vào DB từ internet.

### Cách truy cập Database an toàn (SSH Tunneling)

Nếu bạn cần dùng MySQL Workbench hoặc DBeaver để xem dữ liệu:

1. Cấu hình kết nối qua **SSH**.
2. **SSH Host**: IP của VPS (`trong box`).
3. **SSH User/Pass**: Giống như cách bạn login vào VPS.
4. **MySQL Host**: `db` (Vì API và DB nằm trong cùng mạng Docker).
5. **MySQL User/Pass**: Thông tin trong file `.env`.

---

## 5. Một số lệnh kiểm tra nhanh trên VPS:

- **Xem các dịch vụ đang chạy:** `docker compose ps`
- **Xem log để debug lỗi:** `docker compose logs -f api`
- **Dừng tất cả:** `docker compose down`

---

## 6. Lưu ý chung

- Không bao giờ dùng `git push -f` (force push) lên các nhánh chung (`main`, `develop`).
- Nếu gặp **Conflict** (xung đột code), hãy bình tĩnh, liên hệ người cùng sửa file đó để cùng giải quyết, tránh xóa nhầm code của đồng nghiệp.
