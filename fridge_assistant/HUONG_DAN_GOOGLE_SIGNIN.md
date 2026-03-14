# Hướng dẫn kiểm tra Google Sign-In

## Bước 1: OAuth consent screen – Thêm Test user

1. Vào https://console.cloud.google.com/
2. Chọn project **beptroly**
3. Menu bên trái: **APIs & Services** → **OAuth consent screen**
4. Kéo xuống phần **Test users**
5. Bấm **+ ADD USERS**
6. Thêm email: **doanduymanh11@gmail.com**
7. Bấm **Save**

---

## Bước 2: Kiểm tra OAuth Client IDs

1. Vào **APIs & Services** → **Credentials**
2. Kiểm tra có **2 OAuth 2.0 Client IDs**:

| Loại | Package / Đường dẫn | Cần có |
|------|---------------------|--------|
| **Web application** | Authorized JavaScript origins: http://localhost | Có |
| **Android** | Package: com.example.fridge_assistant, SHA-1: 41:49:E1:D6:0C:88:40:1F:5A:EF:4D:CE:59:7B:2B:96:BA:ED:09:40 | Có |

3. Cả hai phải thuộc **cùng project beptroly**

---

## Bước 3: Lấy Web Client ID

1. Ở trang **Credentials**, bấm vào **Web client** (loại Web application)
2. Copy **Client ID** (dạng: xxx.apps.googleusercontent.com)
3. Đảm bảo file `fridge_assistant/.env` có:
   ```
   GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
   ```

---

## Bước 4: Sau khi sửa

- Đợi 5–10 phút
- Gỡ app cũ trên điện thoại
- Build lại: `flutter build apk`
- Cài APK mới và thử đăng nhập lại
