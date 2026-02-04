#!/bin/bash

# ==========================================
# PHASE 3 DEPLOYMENT SCRIPT - DOCKER VERSION
# ==========================================

set -e  # Exit on any error

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHASE3_DIR="$PROJECT_ROOT/phase3"
NGINX_CONFIG="/etc/nginx/sites-available/notes-app"
NGINX_ENABLED="/etc/nginx/sites-enabled/notes-app"

echo "=========================================="
echo "  PHASE 3: DOCKER DEPLOYMENT SETUP"
echo "=========================================="
echo "Project Root: $PROJECT_ROOT"
echo ""

# ==========================================
# STEP 0: CLEANUP PHASE 2 SERVICES
# ==========================================

echo "🧹 STEP 0: Checking for existing Phase 2 services..."
echo "------------------------------------------"

# --- CHECK 1: JAVA BACKEND SERVICE ---
SERVICE_NAME="backend"

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "⚠️  Found active Phase 2 Backend ($SERVICE_NAME). Stopping..."
    sudo systemctl stop "$SERVICE_NAME"
    sudo systemctl disable "$SERVICE_NAME"
    echo "✅  Stopped and disabled host backend."
else
    echo "✓  Phase 2 Backend is not running (or doesn't exist). Skipping."
fi

# --- CHECK 2: POSTGRESQL HOST SERVICE ---
if systemctl is-active --quiet postgresql 2>/dev/null; then
    echo "⚠️  Found active Host PostgreSQL. Stopping to free port 5432..."
    sudo systemctl stop postgresql
    sudo systemctl disable postgresql
    echo "✅  Stopped and disabled host PostgreSQL."
else
    echo "✓  Host PostgreSQL is not running. Skipping."
fi

# --- CHECK 3: FREE PORTS ---
echo "🛡️  Ensuring ports 8080 and 5432 are free..."
sudo fuser -k 8080/tcp 2>/dev/null || true
sudo fuser -k 5432/tcp 2>/dev/null || true

echo "✅  Cleanup completed."
echo ""

# ==========================================
# STEP 1: INSTALL DEPENDENCIES
# ==========================================

echo "📦 STEP 1: Installing dependencies..."
echo "------------------------------------------"

# Update package list
sudo apt-get update

# Install basic tools
if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    sudo apt-get install -y curl
fi

if ! command -v nginx &> /dev/null; then
    echo "Installing Nginx..."
    sudo apt-get install -y nginx
fi

# Install Certbot for SSL/HTTPS
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot (Let's Encrypt SSL)..."
    sudo apt-get install -y certbot python3-certbot-nginx
    echo "✅  Certbot installed."
else
    echo "✓  Certbot already installed ($(certbot --version 2>&1 | head -1))"
fi

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅  Docker installed. You may need to log out and back in for group changes to take effect."
else
    echo "✓  Docker already installed ($(docker --version))"
fi

# Install Docker Compose
if ! command -v docker compose version &> /dev/null; then
    echo "Installing Docker Compose Plugin..."
    sudo apt-get install -y docker-compose-plugin
else
    echo "✓  Docker Compose already installed ($(docker compose version))"
fi

# Enable Docker to start on boot
sudo systemctl enable docker
sudo systemctl start docker

echo "✅  All dependencies installed."
echo ""

# ==========================================
# STEP 2: CONFIGURE ENVIRONMENT VARIABLES
# ==========================================

echo "🔧 STEP 2: Configuring environment variables..."
echo "------------------------------------------"

cd "$PHASE3_DIR"

if [ -f .env ]; then
    echo "⚠️  .env file already exists."
    read -p "Do you want to reconfigure? (y/N): " RECONFIG
    if [[ ! $RECONFIG =~ ^[Yy]$ ]]; then
        echo "Skipping .env configuration."
    else
        rm .env
    fi
fi

if [ ! -f .env ]; then
    if [ ! -f .env.example ]; then
        echo "❌  .env.example not found!"
        exit 1
    fi
    
    cp .env.example .env
    echo "✅  Created .env from .env.example"
    echo ""
    
    # Prompt for database password only (other values already in .env.example)
    echo "🔐 Database Configuration:"
    echo "------------------------------------------"
    echo "📝  Using default values from .env.example:"
    echo "    - Docker Hub Username: khangtrong"
    echo "    - Image Tag: v1"
    echo "    - Database User: postgres"
    echo "    - Database Name: notes_app_db"
    echo ""
    echo "Please set a secure database password:"
    
    # Prompt for database password (REQUIRED)
    while true; do
        read -sp "Enter database password: " DB_PASSWORD
        echo ""
        read -sp "Confirm database password: " DB_PASSWORD_CONFIRM
        echo ""
        
        if [ "$DB_PASSWORD" == "$DB_PASSWORD_CONFIRM" ]; then
            sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" .env
            break
        else
            echo "❌  Passwords do not match. Please try again."
        fi
    done
    
    echo ""
    echo "✅  Configuration completed."
else
    echo "✓  Using existing .env file."
fi

echo ""

# ==========================================
# STEP 3: PREPARE UPLOADS DIRECTORY
# ==========================================

echo "📁 STEP 3: Preparing uploads directory..."
echo "------------------------------------------"

cd "$PHASE3_DIR"

if [ ! -d uploads ]; then
    mkdir -p uploads
    echo "✅  Created uploads directory."
else
    echo "✓  Uploads directory already exists."
fi

# 1. Cấp quyền 777 cho thư mục uploads
chmod -R 777 uploads
echo "✅  Set permissions (777) for uploads directory."

# 2. [QUAN TRỌNG] Cấp quyền traversal cho thư mục cha
# Để Nginx (www-data) có thể đi từ /home -> /home/ubuntu -> ... -> uploads
echo "🔓 Granting traversal permissions for Nginx (www-data)..."

# Cấp quyền execute cho thư mục dự án (phase root)
chmod o+x "$PROJECT_ROOT"
echo "✅  Set o+x for: $PROJECT_ROOT"

# Cấp quyền execute cho thư mục cha (thường là /home/ubuntu)
PARENT_DIR="$(dirname "$PROJECT_ROOT")"
chmod o+x "$PARENT_DIR"
echo "✅  Set o+x for: $PARENT_DIR"

# Nếu PARENT_DIR là /home/ubuntu, cấp thêm cho /home (optional nhưng an toàn)
if [[ "$PARENT_DIR" == /home/* ]]; then
    chmod o+x /home 2>/dev/null || true
    echo "✅  Set o+x for: /home"
fi

echo "✅  All traversal permissions configured."
echo ""

# ==========================================
# STEP 4: CONFIGURE HOST NGINX (REVERSE PROXY)
# ==========================================

echo "🌐 STEP 4: Configuring Nginx (Reverse Proxy)..."
echo "------------------------------------------"

# Set uploads path
UPLOADS_PATH="$PHASE3_DIR/uploads/"

if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "🗑️  Removing default Nginx config..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

# Remove old config if exists (backup first)
if [ -f "$NGINX_CONFIG" ]; then
    echo "⚠️  Existing Nginx config found. Creating backup..."
    sudo cp "$NGINX_CONFIG" "$NGINX_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    sudo rm "$NGINX_CONFIG"
    echo "✅  Backup created and old config removed."
fi

# Create new config for Phase 3 Docker deployment
echo "Creating new Nginx configuration for Docker containers..."

sudo tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    # --- FRONTEND: Proxy vào Docker Container (Port 3000) ---
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # --- BACKEND: Proxy vào Docker Container (Port 8080) ---
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # --- UPLOADS: Serve file từ thư mục Host (Mount volume) ---
    location /uploads/ {
        alias $UPLOADS_PATH;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Link to sites-enabled if not already linked
if [ ! -L "$NGINX_ENABLED" ]; then 
    sudo ln -s "$NGINX_CONFIG" "$NGINX_ENABLED"
    echo "✅  Linked config to sites-enabled"
fi

# Test and reload nginx
if sudo nginx -t 2>&1 | grep -q "successful"; then
    sudo systemctl reload nginx
    echo "✅  Nginx configuration is valid and reloaded."
else
    echo "⚠️  Nginx configuration test failed."
    sudo nginx -t
    exit 1
fi

echo "✅  Nginx configured for Phase 3 Docker deployment."
echo ""

# ==========================================
# STEP 5: PULL AND START DOCKER CONTAINERS
# ==========================================

echo "🐳 STEP 5: Starting Docker containers..."
echo "------------------------------------------"

cd "$PHASE3_DIR"

# Pull latest images (both backend and frontend from Docker Hub)
echo "Pulling Docker images..."
sudo docker compose pull

# Start containers
echo "Starting containers..."
sudo docker compose up -d

# Wait for containers to be healthy
echo "Waiting for containers to start..."
sleep 15

# Check container status
if sudo docker compose ps | grep -q "Up"; then
    echo "✅  Containers are running."
    sudo docker compose ps
else
    echo "❌  Containers failed to start. Check logs:"
    sudo docker compose logs
    exit 1
fi

echo ""

# ==========================================
# STEP 6: VERIFY DEPLOYMENT
# ==========================================

echo "✅ STEP 6: Verifying deployment..."
echo "------------------------------------------"

# Check if backend is responding
echo "Testing backend API..."
echo "⏳  Waiting for Spring Boot to initialize (this may take 20-30 seconds)..."
sleep 20

if curl -f http://localhost:8080/api/notes > /dev/null 2>&1; then
    echo "✅  Backend API is responding."
else
    echo "⚠️  Backend API not responding yet. It may still be starting."
    echo "    Check logs with: sudo docker compose logs app"
fi

# Check database connection
echo "Testing database connection..."
if sudo docker compose exec -T db pg_isready -U postgres > /dev/null 2>&1; then
    echo "✅  Database is ready."
else
    echo "⚠️  Database not ready yet. Check logs with: sudo docker compose logs db"
fi

# Check frontend container
echo "Testing frontend container..."
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✅  Frontend container is responding."
else
    echo "⚠️  Frontend not responding yet. Check logs with: sudo docker compose logs frontend"
fi

echo ""
echo "=========================================="
echo "  ✅  DEPLOYMENT COMPLETED!"
echo "=========================================="
echo ""

# Check if domain is configured
if [ -f "$NGINX_CONFIG" ]; then
    DOMAIN=$(grep -oP 'server_name \K[^;]+' "$NGINX_CONFIG" | head -1 | xargs)
    if [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "_" ]; then
        echo "🌐 Access your app at: https://$DOMAIN"
    else
        echo "📌 NEXT STEPS: Configure Domain & SSL (Optional)"
        echo "=========================================="
        echo ""
        echo "If you have a domain name, run these commands:"
        echo ""
        echo "1️⃣  Update Nginx with your domain:"
        echo "    sudo sed -i 's/server_name _;/server_name your-domain.com www.your-domain.com;/g' /etc/nginx/sites-available/notes-app"
        echo "    sudo nginx -t"
        echo "    sudo systemctl reload nginx"
        echo ""
        echo "2️⃣  Enable HTTPS with Let's Encrypt:"
        echo "    sudo certbot --nginx"
        echo ""
        echo "    Follow prompts:"
        echo "    - Enter email address"
        echo "    - Agree to Terms of Service"
        echo "    - Choose: Redirect HTTP to HTTPS (recommended)"
        echo ""
        echo "After setup, access your app at: https://your-domain.com"
    fi
fi

echo ""
echo "🌐 Access your app at: http://$(curl -s ifconfig.me)"

