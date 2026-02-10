#!/bin/bash
# ==========================================
# Bếp Trợ Lý - VPS Deployment Script
# Ubuntu Server Setup
# ==========================================
set -e

APP_NAME="bep-tro-ly"
APP_DIR="/opt/$APP_NAME"
# APP_USER="www-data" # Not used, running as root for simplicity
PYTHON_VERSION="python3"

echo "=========================================="
echo "  Bếp Trợ Lý - VPS Deployment"
echo "=========================================="

# 1. Update system
echo "[1/6] Updating system packages..."
apt update && apt upgrade -y

# 2. Install dependencies
echo "[2/6] Installing Python & dependencies..."
apt install -y python3 python3-pip python3-venv

# 3. Setup app directory
echo "[3/6] Setting up application directory..."
mkdir -p $APP_DIR
cp -r ./* $APP_DIR/ 2>/dev/null || true
cd $APP_DIR

# Remove unnecessary files
rm -rf fridge_assistant/ .venv/ __pycache__/ models/__pycache__/ services/__pycache__/
rm -f deploy.sh db_structure.txt inspect_db.py

# 4. Create virtualenv & install packages
echo "[4/6] Creating virtual environment..."
$PYTHON_VERSION -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 5. Create .env file
echo "[5/6] Creating environment config..."
if [ ! -f .env ]; then
  echo "Creating .env file from template..."
  # NOTE: Replace these values with actual secrets on the server
  cat > .env << 'EOF'
SECRET_KEY=replace_me_on_server
GEMINI_API_KEY=replace_me_on_server
TIDB_HOST=replace_me_on_server
TIDB_PORT=4000
TIDB_USER=replace_me_on_server
TIDB_PASSWORD=replace_me_on_server
TIDB_DATABASE=Bep_Tro_Ly
PORT=5000
FLASK_DEBUG=false
EOF
  echo "  -> .env created (Please update with real values!)"
else
  echo "  -> .env already exists, skipping"
fi

# 6. Create systemd service
echo "[6/6] Creating systemd service..."
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=Bếp Trợ Lý API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 --timeout 120 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable $APP_NAME
systemctl restart $APP_NAME

echo ""
echo "=========================================="
echo "  ✅ Deployment Complete!"
echo "=========================================="
echo "  API: http://$(hostname -I | awk '{print $1}'):5000/"
echo "  Status: systemctl status $APP_NAME"
echo "  Logs: journalctl -u $APP_NAME -f"
echo "  IMPORTANT: Update .env with real credentials!"
echo "=========================================="
