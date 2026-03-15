# Bep Tro Ly

Ung dung quan ly thuc pham trong tu lanh, goi y mon an bang AI, va quan ly meal plan.

## Tong Quan

- Backend: `.NET 8` + `EF Core Code First` + `MySQL`
- Mobile App: `Flutter`
- Deployment: `Docker Compose` tren VPS Ubuntu

## Cau Truc Thu Muc

- `dotnet_backend/BepTroLy.API`: API backend
- `fridge_assistant`: Flutter app
- `docker-compose.yml`: Chay API + MySQL bang Docker
- `.env.example`: Mau bien moi truong

## Yeu Cau Cai Dat

- Docker + Docker Compose
- .NET SDK 8.0 (neu chay backend local)
- Flutter SDK (neu chay mobile local)

## Chay Nhanh Bang Docker (Khuyen Dung)

1. Tao file `.env` tu file mau:

```bash
cp .env.example .env
```

2. Dien gia tri that trong `.env`:

- `DB_PASSWORD`
- `JWT_SECRET`
- `GEMINI_API_KEY`
- `GOOGLE_CLIENT_ID`

3. Build va chay:

```bash
docker compose up -d --build
```

4. Kiem tra trang thai:

```bash
docker compose ps
docker compose logs -f db
docker compose logs -f api
```

## Endpoint Co Ban

- API base: `http://<VPS_IP>:5001`
- Health check: `GET /health`
- Swagger: `http://<VPS_IP>:5001/swagger`

## Luu Y Database (Code First)

- Migration duoc apply tu dong khi API startup (`context.Database.Migrate()`).
- Docker da duoc cau hinh healthcheck cho MySQL va API se doi DB `healthy` truoc khi khoi dong.
- MySQL server version duoc set ro rang qua `Database:ServerVersion` de tranh loi `AutoDetect`.

## Bao Mat

- Khong commit file `.env`.
- Khong dua secret that vao `appsettings*.json`.
- Neu nghi ngo lo secret: doi ngay `DB_PASSWORD`, `JWT_SECRET`, `GEMINI_API_KEY`.

## Lenh Thuong Dung

```bash
docker compose up -d --build
docker compose down
docker compose logs -f api
docker compose logs -f db
```

## Deploy 1 Lenh Tren VPS Linux

Sau khi SSH vao VPS, chay:

```bash
cd /root/bep-tro-ly
chmod +x deploy.sh
./deploy.sh
```

Tuy chon bien moi truong:

```bash
APP_DIR=/root/bep-tro-ly BRANCH=dev HEALTH_URL=http://127.0.0.1:5001/health ./deploy.sh
```

## Rollback Nhanh Tren VPS Linux

Neu ban deploy xong ma API loi, rollback ve commit truoc do:

```bash
cd /root/bep-tro-ly
chmod +x rollback.sh
./rollback.sh
```

Tuy chon bien moi truong:

```bash
APP_DIR=/root/bep-tro-ly BRANCH=dev HEALTH_URL=http://127.0.0.1:5001/health ./rollback.sh
```

Luu y: `rollback.sh` dung `git reset --hard HEAD~1`, chi dung khi thu muc code tren VPS khong co thay doi thu cong chua commit.

## Quy Trinh Git Ngan

```bash
git checkout develop
git pull origin develop
git checkout -b feature/ten-tinh-nang
```

Mo Pull Request vao `develop` sau khi hoan thanh.
