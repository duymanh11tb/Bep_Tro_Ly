#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/root/bep-tro-ly}"
BRANCH="${BRANCH:-dev}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:5001/health}"

echo "[1/5] Enter project directory: ${APP_DIR}"
cd "${APP_DIR}"

echo "[2/5] Update source from origin/${BRANCH}"
git fetch origin
git checkout "${BRANCH}"
git pull --ff-only origin "${BRANCH}"

echo "[3/5] Build and restart containers"
docker compose up -d --build

echo "[4/5] Show compose status"
docker compose ps

echo "[5/5] Health check: ${HEALTH_URL}"
if curl -fsS "${HEALTH_URL}"; then
  echo
  echo "Deploy completed successfully."
else
  echo
  echo "Health check failed. Run: docker compose logs -f api"
  exit 1
fi
