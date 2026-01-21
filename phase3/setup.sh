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
    
    echo ""
    echo "✅  Environment variables configured."
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

chmod 755 uploads
echo "✅  Set permissions for uploads directory."
echo ""

# ==========================================
# STEP 4: CONFIGURE NGINX
# ==========================================

echo "🌐 STEP 4: Configuring Nginx..."
echo "------------------------------------------"

# Check if nginx config exists
if [ -f "$NGINX_CONFIG" ]; then
    echo "✓  Found existing Nginx config at $NGINX_CONFIG"
    
    # Update uploads path to point to phase3/uploads
    UPLOADS_PATH="$PHASE3_DIR/uploads/"
    
    # Check if alias line exists
    if grep -q "alias.*uploads" "$NGINX_CONFIG"; then
        echo "Updating uploads path in Nginx config..."
        sudo sed -i "s|alias .*/uploads/.*|alias $UPLOADS_PATH;|g" "$NGINX_CONFIG"
        echo "✅  Updated uploads path to: $UPLOADS_PATH"
    else
        echo "⚠️  No uploads alias found in Nginx config."
        echo "Please manually add this location block to $NGINX_CONFIG:"
        echo ""
        echo "    location /uploads/ {"
        echo "        alias $UPLOADS_PATH;"
        echo "        expires 1y;"
        echo "        add_header Cache-Control \"public, immutable\";"
        echo "    }"
    fi
else
    echo "⚠️  Nginx config not found. Creating new config..."
    
    if [ ! -f "$PROJECT_ROOT/phase2/configs/nginx.conf" ]; then
        echo "❌  Template config not found at phase2/configs/nginx.conf"
        echo "Please create Nginx config manually."
    else
        # Copy template and replace variables
        sudo cp "$PROJECT_ROOT/phase2/configs/nginx.conf" "$NGINX_CONFIG"
        
        # Replace PROJECT_ROOT variable
        sudo sed -i "s|\${PROJECT_ROOT}|$PROJECT_ROOT|g" "$NGINX_CONFIG"
        
        # Update uploads path to phase3
        sudo sed -i "s|phase1/app/backend/uploads/|phase3/uploads/|g" "$NGINX_CONFIG"
        
        # Create symbolic link if not exists
        if [ ! -L "$NGINX_ENABLED" ]; then
            sudo ln -s "$NGINX_CONFIG" "$NGINX_ENABLED"
        fi
        
        echo "✅  Created Nginx config from template."
    fi
fi

# Test nginx config
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo "✅  Nginx configuration is valid."
    sudo systemctl reload nginx
    echo "✅  Nginx reloaded."
else
    echo "⚠️  Nginx configuration test failed. Please check manually."
fi

echo ""

# ==========================================
# STEP 5: PULL AND START DOCKER CONTAINERS
# ==========================================

echo "🐳 STEP 5: Starting Docker containers..."
echo "------------------------------------------"

cd "$PHASE3_DIR"

# Pull latest images
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

echo ""
echo "=========================================="
echo "  DEPLOYMENT COMPLETED!"
echo "=========================================="
echo ""
echo "📋 Useful Commands:"
echo "  View logs:           sudo docker compose logs -f"
echo "  View app logs:       sudo docker compose logs -f app"
echo "  View db logs:        sudo docker compose logs -f db"
echo "  Stop containers:     sudo docker compose down"
echo "  Restart containers:  sudo docker compose restart"
echo "  Check status:        sudo docker compose ps"
echo ""
echo "🌐 Application URLs:"
echo "  Backend API:         http://localhost:8080/api/notes"
echo "  Uploads:             http://localhost:8080/uploads/"
if [ -f "$NGINX_CONFIG" ]; then
    DOMAIN=$(grep -oP 'server_name \K[^;]+' "$NGINX_CONFIG" | head -1 | xargs)
    if [ ! -z "$DOMAIN" ] && [ "$DOMAIN" != "_" ]; then
        echo "  Public Domain:       https://$DOMAIN"
    fi
fi
echo ""
echo "✅  Phase 3 deployment completed successfully!"
