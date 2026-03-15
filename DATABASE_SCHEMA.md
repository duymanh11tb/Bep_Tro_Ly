# Tài liệu Cấu trúc Cơ sở dữ liệu - Bếp Trợ Lý

Hệ thống sử dụng cơ sở dữ liệu quan hệ (MySQL/TiDB). Dưới đây là bảng tổng hợp các bảng và trường dữ liệu chính.

---

## 1. Người dùng & Phân quyền (`users`)
Bảng lưu trữ thông tin tài khoản và thiết lập cá nhân.

| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `user_id` | Int (PK) | ID duy nhất |
| `email` | Varchar(255) | Email đăng nhập (Unique) |
| `password_hash` | Varchar(255) | Mật khẩu đã mã hóa |
| `display_name` | Varchar(100) | Tên hiển thị |
| `role` | Longtext | Vai trò: `User`, `Admin` |
| `preferred_language` | Varchar(10) | Ngôn ngữ ưu tiên (`vi`, `en`) |
| `ui_theme` | Varchar(20) | Chế độ giao diện (`light`, `dark`) |
| `measurement_unit` | Varchar(20) | Đơn vị đo lường (`metric`, `imperial`) |
| `dietary_restrictions`| JSON | Chế độ ăn uống |
| `cuisine_preferences` | JSON | Sở thích ẩm thực |
| `notification_time` | Time | Giờ nhận thông báo |
| `last_active` | DateTime | Lần hoạt động cuối |

---

## 2. Quản lý thực phẩm (`pantry_items` & `categories`)

### Bảng `pantry_items` (Thực phẩm trong tủ)
| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `item_id` | Int (PK) | ID thực phẩm |
| `user_id` | Int (FK) | Liên kết người dùng |
| `category_id` | Int (FK) | Liên kết danh mục |
| `name_vi` | Varchar(200) | Tên tiếng Việt |
| `quantity` | Decimal | Số lượng |
| `unit` | Varchar(20) | Đơn vị (kg, quả, gói...) |
| `location` | Longtext | Vị trí: `Fridge`, `Freezer`, `Pantry` |
| `fridge_id` | Int (FK) | Liên kết Tủ lạnh ảo (Nullable) |
| `expiry_date` | Date | Ngày hết hạn |
| `status` | Longtext | Trạng thái: `active`, `consumed`, `expired` |

### Bảng `categories` (Danh mục)
| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `category_id` | Int (PK) | ID danh mục |
| `category_code` | Varchar(50) | Mã định danh |
| `name_vi` | Varchar(100) | Tên hiển thị |
| `default_fridge_days`| Int | Hạn dùng mặc định trong ngăn mát |

---

## 3. Công thức nấu ăn (`recipes` & `recipe_ingredients`)

### Bảng `recipes`
| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `recipe_id` | Int (PK) | ID công thức |
| `title_vi` | Varchar(255) | Tên món ăn |
| `instructions` | JSON | Các bước nấu ăn |
| `cook_time` | Int | Thời gian nấu (phút) |
| `difficulty` | Longtext | Độ khó: `easy`, `medium`, `hard` |
| `calories` | Int | Lượng calo |
| `rating_average` | Decimal | Điểm đánh giá trung bình |

### Bảng `recipe_ingredients`
| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `ingredient_id` | Int (PK) | ID nguyên liệu |
| `recipe_id` | Int (FK) | Thuộc công thức nào |
| `name_vi` | Varchar(200) | Tên nguyên liệu |

---

## 4. Kế hoạch & Mua sắm

- **`meal_plans` & `meal_plan_items`**: Quản lý lịch ăn uống theo tuần.
- **`shopping_lists` & `shopping_list_items`**: Quản lý danh sách đồ cần mua, trạng thái đã mua/chưa mua và giá cả.

---

## 5. Hệ thống bổ trợ
- **`notifications`**: Lưu lịch sử thông báo đẩy.
- **`activity_logs`**: Nhật ký hành động của người dùng.
- **`ai_recipe_cache`**: Lưu trữ kết quả AI Gemini để tối ưu hiệu năng.
- **`virtual_fridges`**: Quản lý nhiều tủ lạnh (Nhà, Văn phòng).
- **`fridge_members`**: Quản lý thành viên cùng sở hữu/sử dụng tủ lạnh.
- **`feedbacks`**: Hệ thống phản hồi từ người dùng.

## Chi tiết các bảng mới

### 6. Tủ lạnh ảo (`virtual_fridges`)
| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `fridge_id` | Int (PK) | ID tủ lạnh |
| `name` | Varchar(100) | Tên tủ lạnh |
| `owner_id` | Int (FK) | Người tạo tủ lạnh |

### 7. Thành viên tủ lạnh (`fridge_members`)
| Trường | Kiểu dữ liệu | Ghi chú |
| :--- | :--- | :--- |
| `fridge_id` | Int (FK) | ID tủ lạnh |
| `user_id` | Int (FK) | ID người dùng |
| `role` | Varchar(20) | `owner`, `member` |
| `status` | Varchar(20) | `active`, `invited` |

*Tài liệu được cập nhật dựa trên yêu cầu mới về tính năng Social Fridge.*

*Tài liệu được cập nhật tự động dựa trên AppDbContextModelSnapshot.*
