#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/root/bep-tro-ly}"
BRANCH="${BRANCH:-dev}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:5001/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_SLEEP_SECONDS="${HEALTH_SLEEP_SECONDS:-2}"

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
for attempt in $(seq 1 "${HEALTH_RETRIES}"); do
  if curl -fsS "${HEALTH_URL}"; then
    echo
    echo "Deploy completed successfully."
    exit 0
  fi

  echo
  echo "Health check attempt ${attempt}/${HEALTH_RETRIES} failed. Waiting ${HEALTH_SLEEP_SECONDS}s..."
  sleep "${HEALTH_SLEEP_SECONDS}"
done

echo
echo "Health check failed after ${HEALTH_RETRIES} attempts. Recent API logs:"
docker compose logs --tail 200 api || true
exit 1
