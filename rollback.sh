#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/root/bep-tro-ly}"
BRANCH="${BRANCH:-dev}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:5001/health}"

echo "[1/6] Enter project directory: ${APP_DIR}"
cd "${APP_DIR}"

echo "[2/6] Ensure working tree is clean"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit/stash changes before rollback."
  exit 1
fi

echo "[3/6] Checkout ${BRANCH} and fetch latest refs"
git checkout "${BRANCH}"
git fetch origin

echo "[4/6] Roll back one commit (HEAD~1)"
git reset --hard HEAD~1

echo "[5/6] Rebuild and restart containers"
docker compose up -d --build
docker compose ps

echo "[6/6] Health check: ${HEALTH_URL}"
if curl -fsS "${HEALTH_URL}"; then
  echo
  echo "Rollback completed successfully."
else
  echo
  echo "Health check failed after rollback. Check logs: docker compose logs -f api"
  exit 1
fi
