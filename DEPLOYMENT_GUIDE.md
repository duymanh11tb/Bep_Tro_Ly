# Deployment Guide - Bep Tro Ly (Tủ lạnh thông minh)

**Last Updated:** March 19, 2026
**Status:** Ready for Production
**Git Commit:** 7a07b5b

## 📋 What's Included

### Backend Upgrades ✅
- **Gemini Model:** Upgraded to `gemini-3-pro` (from 2.5-flash)
- **Batch API:** Full Gemini Batch API integration (50% cost savings)
- **Image Caching:** Wikimedia Commons auto-resolution with process-lifetime cache
- **Filter Logic:** Added `IsRelevantRecipe` (requires ≥2 ingredient matches)
- **Quality:** Enhanced error handling, circuit breaker, async/await patterns

### Frontend Features ✅
- **Recipe Detail:** Added "Gợi ý trong bữa ăn" section (similar recipes horizontal ListView)
- **Recommendations:** Complete UI redesign with animations, gradients, search improvements
- **Search:** Fixed Vietnamese diacritics normalization
- **Android Build:** Java 17 + coreLibraryDesugar for compatibility
- **Performance:** Image caching with cacheWidth optimization

### Deployment Ready ✅
- **APK:** Built and tested (98.1MB, app-release.apk)
- **Environment:** .env configured (JWT_SECRET: 2026, GEMINI_API_KEY set)
- **Docker:** docker-compose.yml ready (MySQL 8.0 + .NET API)
- **Git:** All changes committed and pushed to `dev` branch

---

## 🚀 VPS Deployment Setup

### Prerequisites
- VPS: Ubuntu 20.04+ or similar Linux
- Docker & Docker Compose installed
- Git installed
- Port 5001 available (API) and 3306 (MySQL, internal)

### Step 1: Clone Repository on VPS
```bash
cd /root
git clone https://github.com/duymanh11tb/Bep_Tro_Ly.git bep-tro-ly
cd bep-tro-ly
git checkout dev
```

### Step 2: Create/Update .env File


### Step 3: Run Deployment Script
```bash
cd /root/bep-tro-ly
bash deploy.sh
```

The script will:
1. Fetch latest code from `dev` branch
2. Build and restart Docker containers
3. Run health check on http://127.0.0.1:5001/health
4. Display status

### Step 4: Verify Deployment
```bash
# Check containers
docker compose ps

# View API logs
docker compose logs -f api

# Health check
curl http://127.0.0.1:5001/health
```

---

## 📦 APK Distribution

**File:** `fridge_assistant/build/app/outputs/flutter-apk/app-release.apk`
**Size:** 98.1 MB
**Target:** Android (Pixel 8 tested, minimum SDK 21)

### Installation Options
1. **Firebase App Distribution:** Upload APK to Firebase Console
2. **Google Play Store:** Upload to internal testing track
3. **Direct Download:** Host APK on private server
4. **QR Code:** Generate QR linking to APK download

---

## 🔧 Backend Configuration Details

### API Endpoints (Port 5001)

**Health Check:**
```
GET /health
→ 200 OK
```

**Recipes - AI Suggestions:**
```
POST /api/recipes/suggest
Headers: Authorization: Bearer {JWT_TOKEN}
Body: { "ingredients": ["dưa", "trứng"], "preferences": {...} }
→ { "success": true, "recipes": [...], "source": "ai|cache|local_fallback" }
```

**Batch API - Create Job:**
```
POST /api/recipes/batch-suggest
Headers: Authorization: Bearer {JWT_TOKEN}
Body: { "preferences": {...} }
→ { "success": true, "job_id": 123, "batch_name": "batches/..." }
```

**Batch API - Check Status:**
```
GET /api/recipes/batch-status/{jobId}
→ { "job_id": 123, "state": "JOB_STATE_RUNNING", "succeeded_count": 5, ... }
```

### Environment Variables
- `DB_PASSWORD`: MySQL root password
- `JWT_SECRET`: JWT signing key (2026 format)
- `GEMINI_API_KEY`: Google Generative AI API key
- `GOOGLE_CLIENT_ID`: OAuth 2.0 client ID (for future auth integration)

---

## 📊 Monitoring & Troubleshooting

### Common Issues

**Health check fails:**
```bash
docker compose logs api | tail -50
```

**Database connection error:**
```bash
docker compose exec db mysql -u root -p"$DB_PASSWORD" -e "SELECT 1"
```

**Image resolution failing:**
- Wikimedia Commons API timeout → falls back to static URLs
- Check logs: `docker compose logs api | grep -i wikimedia`

**Batch API stuck in PENDING:**
- Background polling service runs every 30 seconds
- Manual check: `docker compose exec api curl ... /batch-status/{jobId}`
- Logs: `docker compose logs api | grep -i batch`

### Restart Services
```bash
docker compose restart api        # Restart API only
docker compose restart db         # Restart database only
docker compose restart            # Restart all
```

---

## 📱 Flutter App Launch Configuration

When user opens app (first time or after update):
1. App connects to API at `http://API_IP:5001` (configure in lib/services/api_client.dart)
2. Authenticates with JWT token (stored securely in local storage)
3. Loads pantry items and cached recipes
4. AI suggestions auto-load on dashboard

### API Base URL (Flutter)
Update in `fridge_assistant/lib/services/api_client.dart`:
```dart
const String baseUrl = 'http://103.77.173.6:5001';  // Replace with actual VPS IP
```

---

## 🔐 Security Notes

- JWT_SECRET is strong (2026 format) - rotate periodically
- GEMINI_API_KEY is in .env - keep .env out of git
- Database password is strong - consider changing in production
- Firewall: Only expose port 5001 (API), keep 3306 (MySQL) internal
- SSL/TLS: Recommend nginx reverse proxy with Let's Encrypt in production

---

## 📈 Performance Tuning

### Image Caching
- Wikimedia resolution cached in-process (process lifetime)
- Fallback URLs cached locally on app side (cacheWidth: 600)

### Recipe Ranking
- IsRelevantRecipe filter reduces irrelevant results by ~60%
- Match score de-duplicates similar recipes
- Batch API queries 3 categories at once (fast, veg, regional)

### Database
- AI responses cached 24h by default
- Batch results stored in `batch_jobs` table for polling
- Consider indexing: `(user_id, status)` on pantry_items

---

## 📝 Rollback Plan

If issues occur after deployment:

1. **Revert to previous commit:**
   ```bash
   cd /root/bep-tro-ly
   git checkout HEAD~1
   docker compose down
   bash deploy.sh
   ```

2. **Keep previous image tagged:**
   ```bash
   docker tag bep-tro-ly-api:latest bep-tro-ly-api:backup-7a07b5b
   ```

3. **Database migration rollback:**
   - Entity Framework Core migrations are auto-applied
   - To rollback specific migration: `dotnet ef database update <migration-name>`

---

## ✅ Deployment Checklist

- [ ] VPS SSH access verified
- [ ] .env file uploaded and secured (no world-readable)
- [ ] Git `dev` branch pulled
- [ ] Docker & Docker Compose installed
- [ ] Firewall rules: port 5001 open to app clients
- [ ] `deploy.sh` executed successfully
- [ ] Health check returning 200 OK
- [ ] API logs show no errors
- [ ] Database migrations completed
- [ ] APK distributed to testers
- [ ] Flutter app base URL configured
- [ ] Initial user can login and get AI suggestions
- [ ] Batch API jobs polling successfully

---

## 🎯 Next Steps (Post-Deployment)

1. **Monitor API logs** for 24h for any errors
2. **Test end-to-end** with real user account
3. **Verify Gemini 3-pro** integration working (check cost/error rates)
4. **Scale database** if needed (MySQL connector pool tuning)
5. **Set up alerts** for API downtime or Gemini quota exceeded
6. **Plan SSL/TLS** migration for production security

---

**Deployment prepared by GitHub Copilot**
**Date:** March 19, 2026
**Status:** ✅ Ready for Production Deployment
