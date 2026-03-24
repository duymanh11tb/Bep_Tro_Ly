# Bếp Trợ Lý

Ứng dụng trợ lý bếp thông minh, giúp bạn:
- Quản lý thực phẩm trong tủ lạnh
- Gợi ý công thức theo nguyên liệu hiện có
- Lập kế hoạch bữa ăn (meal plan) và theo dõi sử dụng thực phẩm

## Ứng Dụng Hoạt Động Như Thế Nào

Hệ thống gồm 3 phần chính:
- `dotnet_backend/BepTroLy.API`: REST API .NET 8, xử lý nghiệp vụ, xác thực, kết nối MySQL
- `fridge_assistant`: ứng dụng Flutter (mobile/web) cho người dùng cuối
- `landing_web`: trang giới thiệu (landing page)

Luồng xử lý chính:
1. Người dùng cập nhật danh sách thực phẩm trong tủ lạnh.
2. API phân tích nguyên liệu, kết hợp dịch vụ gợi ý công thức.
3. Hệ thống trả về món phù hợp, hướng dẫn nấu và gợi ý theo sở thích.
4. Người dùng lưu vào meal plan để theo dõi và sử dụng thực phẩm hiệu quả hơn.

## Công Nghệ Sử Dụng

- Backend: `.NET 8`, `ASP.NET Core`, `EF Core Code First`, `MySQL`
- Mobile app: `Flutter`
- Vận hành: `Docker Compose`
- Dịch vụ gợi ý công thức: `Spoonacular` (+ AI dịch/tạo mẹo qua Gemini nếu cấu hình)

## Cấu Trúc Thư Mục

- `dotnet_backend/`: mã nguồn backend và Dockerfile
- `fridge_assistant/`: mã nguồn ứng dụng Flutter
- `landing_web/`: mã nguồn trang landing
- `docker-compose.yml`: khởi chạy API + DB
- `.env.example`: mẫu biến môi trường
- `deploy.sh`, `rollback.sh`: script deploy/rollback trên VPS Linux

## Hướng Dẫn Sử Dụng Nhanh

### 1) Chạy bằng Docker (khuyến dùng)

Tạo file môi trường:
```bash
cp .env.example .env
```

Điền các biến quan trọng:
- `DB_PASSWORD`
- `JWT_SECRET`
- `SPOONACULAR_API_KEY`
- `GOOGLE_CLIENT_ID`
- `GEMINI_API_KEY` (nếu cần AI dịch/tạo mẹo)

Khởi động hệ thống:
```bash
docker compose up -d --build
```

Kiểm tra trạng thái:
```bash
docker compose ps
docker compose logs -f db
docker compose logs -f api
```

### 2) Truy cập dịch vụ

- API base: `http://<VPS_IP>:5001`
- Health check: `GET /health`
- Swagger: `http://<VPS_IP>:5001/swagger`

### 3) Cấu hình Flutter API URL

Flutter app đọc biến môi trường từ `fridge_assistant/assets/.env`.
Mẫu cấu hình trong `fridge_assistant/assets/.env.example`:

```env
API_URL=<IP_VPS>:5001
API_URL_WEB=auto
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
```

Khuyến nghị production:
- Đặt frontend web và API cùng domain/HTTPS qua reverse proxy
- Giữ `API_URL_WEB=auto` để tránh lỗi CORS/origin

## Hướng Dẫn Vận Hành Trên VPS

Deploy nhanh:
```bash
cd ~/Bep_Tro_Ly
chmod +x deploy.sh
./deploy.sh
```

Rollback nhanh:
```bash
cd ~/Bep_Tro_Ly
chmod +x rollback.sh
./rollback.sh
```

Tùy chọn biến môi trường khi deploy/rollback:
```bash
APP_DIR=~/Bep_Tro_Ly BRANCH=main HEALTH_URL=http://127.0.0.1:5001/health ./deploy.sh
APP_DIR=~/Bep_Tro_Ly BRANCH=main HEALTH_URL=http://127.0.0.1:5001/health ./rollback.sh
```

Thành viên phát triển dự án :

Đoàn Duy Mạnh – Code chính

- Xây dựng Database

- Phát triển API

- Thiết kế và xây dựng giao diện

Lương Quang Huy – Code phụ

- Xây dựng giao diện

- Chức năng thông tin cá nhân

- Chức năng đăng nhập

Trần Hậu Huân – Code phụ

- Xây dựng giao diện

- Chức năng thêm/sửa/xóa sản phẩm

## 📞 Thông tin liên hệ

- ✉️ Email: doanduymanh11@gmail.com  
- 📱 Phone: 0865060731

