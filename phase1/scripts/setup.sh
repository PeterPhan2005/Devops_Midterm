#!/bin/bash

# ============================================
# SETUP & BUILD AUTOMATION SCRIPT
# ============================================
# This script installs dependencies, configures database,
# and builds production artifacts (JAR + static files)
# For use with Systemd + Nginx deployment

# Get script directory (phase1/scripts/), then go back 1 level to phase1/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE1_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 SETUP & BUILD AUTOMATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Script location: $SCRIPT_DIR"
echo "📍 Phase1 root: $PHASE1_ROOT"
echo ""

# Navigate to phase1 root
if [ ! -d "$PHASE1_ROOT" ]; then
    echo "❌ Error: phase1 root not found at $PHASE1_ROOT"
    exit 1
fi

cd "$PHASE1_ROOT"
echo "✓ Working directory: $(pwd)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# LOAD ENVIRONMENT VARIABLES FROM .env
# ============================================

ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading environment variables from .env..."
    # Export variables from .env file
    set -a
    source "$ENV_FILE"
    set +a
    echo -e "${GREEN}✓ Environment variables loaded${NC}"
else
    echo -e "${YELLOW}⚠ .env file not found. Creating from template...${NC}"
    
    # Create .env from example
    if [ ! -f "$SCRIPT_DIR/.env.example" ]; then
        echo -e "${RED}❌ Error: .env.example not found${NC}"
        exit 1
    fi
    
    cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
    echo -e "${GREEN}✓ Created .env file${NC}"
    echo ""
    
    # Prompt for database password (secure input with hidden characters)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}🔐 Database Configuration${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}Please enter PostgreSQL password for user 'postgres':${NC}"
    echo -e "${YELLOW}(Input will be hidden for security)${NC}"
    echo ""
    
    # Read password securely (-s hides input, -r prevents backslash escaping)
    read -rsp "DB Password: " USER_DB_PASS
    echo "" # New line after hidden input
    
    # Validate password is not empty
    if [ -z "$USER_DB_PASS" ]; then
        echo -e "${RED}❌ Error: Password cannot be empty${NC}"
        rm -f "$ENV_FILE"
        exit 1
    fi
    
    # Update .env file with user password using sed
    # Use | as delimiter to avoid issues with / in password
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$USER_DB_PASS|" "$ENV_FILE"
    
    echo -e "${GREEN}✓ Database password saved to .env${NC}"
    echo ""
    
    # Reload environment variables
    set -a
    source "$ENV_FILE"
    set +a
fi

# Validate required variables (Prevent security hardcode issues)
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}❌ Error: DB_PASSWORD is not set in .env${NC}"
    exit 1
fi

# Database Configuration (read from environment or use defaults)
DB_NAME="${DB_NAME:-notes_app_db}"
DB_USER="${DB_USER:-postgres}"

echo "⚙️  Configuration:"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo ""

# ============================================
# STEP 1: CHECK AND INSTALL PREREQUISITES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 STEP 1: Installing Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if [ -f /etc/debian_version ]; then
        PKG_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        PKG_MANAGER="yum"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    PKG_MANAGER="brew"
else
    echo -e "${RED}❌ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

echo "Detected OS: $OS (Package manager: $PKG_MANAGER)"
echo ""

# Function to install packages
install_package() {
    local package=$1
    
    # Check if already installed
    if command -v "$package" &> /dev/null 2>&1 || dpkg -s "$package" &> /dev/null 2>&1; then
        echo "✓ $package is already installed"
        return 0
    fi
    
    echo "Installing $package..."
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        sudo apt update -qq && sudo apt install -y "$package"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        sudo yum install -y "$package"
    elif [ "$PKG_MANAGER" == "brew" ]; then
        brew install "$package"
    fi
}

# Install Basic Tools
echo -n "Checking curl... "
install_package "curl"

echo -n "Checking git... "
install_package "git"

# Check Java 21 specifically
echo -n "Checking Java 21... "
JAVA_21_INSTALLED=false

if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
    if [ "$JAVA_VERSION" == "21" ]; then
        echo -e "${GREEN}✓ Found (Java 21)${NC}"
        JAVA_21_INSTALLED=true
    else
        echo -e "${YELLOW}✗ Found Java $JAVA_VERSION, but need Java 21${NC}"
    fi
else
    echo -e "${YELLOW}✗ Not found${NC}"
fi

# Install Java 21 if not present
if [ "$JAVA_21_INSTALLED" = false ]; then
    echo "Installing Java 21..."
    if [ "$PKG_MANAGER" == "apt" ]; then
        install_package "openjdk-21-jdk"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        install_package "java-21-openjdk-devel"
    elif [ "$PKG_MANAGER" == "brew" ]; then
        install_package "openjdk@21"
    fi
    
    # Set Java 21 as default
    if [ "$PKG_MANAGER" == "apt" ] || [ "$PKG_MANAGER" == "yum" ]; then
        echo "Setting Java 21 as default..."
        sudo update-alternatives --set java /usr/lib/jvm/java-21-openjdk-amd64/bin/java 2>/dev/null || \
        sudo update-alternatives --auto java 2>/dev/null
    fi
    
    # Verify installation
    if command -v java &> /dev/null; then
        NEW_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
        echo -e "${GREEN}✓ Java $NEW_VERSION installed${NC}"
    fi
fi

# Check Maven
echo -n "Checking Maven... "
if command -v mvn &> /dev/null; then
    MVN_VERSION=$(mvn -version | head -n 1 | awk '{print $3}')
    echo -e "${GREEN}✓ Found (Maven $MVN_VERSION)${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
    install_package "maven"
fi

# Check Nginx (NEW FOR PHASE 2 - Reverse Proxy)
echo -n "Checking Nginx... "
if command -v nginx &> /dev/null; then
    NGINX_VERSION=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
    echo -e "${GREEN}✓ Found (Nginx $NGINX_VERSION)${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
    install_package "nginx"
fi

# Check PostgreSQL
echo -n "Checking PostgreSQL... "
if command -v psql &> /dev/null; then
    PG_VERSION=$(psql --version | awk '{print $3}')
    echo -e "${GREEN}✓ Found (PostgreSQL $PG_VERSION)${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
    if [ "$PKG_MANAGER" == "apt" ]; then
        install_package "postgresql"
        install_package "postgresql-contrib"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        install_package "postgresql-server"
        install_package "postgresql-contrib"
        sudo postgresql-setup --initdb
    elif [ "$PKG_MANAGER" == "brew" ]; then
        install_package "postgresql"
    fi
fi

# Start PostgreSQL service
echo -n "Starting PostgreSQL service... "
if [ "$OS" == "linux" ]; then
    sudo systemctl start postgresql 2>/dev/null || sudo service postgresql start 2>/dev/null
    sudo systemctl enable postgresql 2>/dev/null
elif [ "$OS" == "mac" ]; then
    brew services start postgresql 2>/dev/null
fi
echo -e "${GREEN}✓${NC}"

# Start Nginx service (NEW FOR PHASE 2)
echo -n "Starting Nginx service... "
if [ "$OS" == "linux" ]; then
    sudo systemctl start nginx 2>/dev/null || sudo service nginx start 2>/dev/null
    sudo systemctl enable nginx 2>/dev/null
elif [ "$OS" == "mac" ]; then
    brew services start nginx 2>/dev/null
fi
echo -e "${GREEN}✓${NC}"

# Check Node.js
echo -n "Checking Node.js... "
if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Found ($NODE_VERSION)${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
    if [ "$PKG_MANAGER" == "apt" ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        install_package "nodejs"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        install_package "nodejs"
    elif [ "$PKG_MANAGER" == "brew" ]; then
        install_package "node"
    fi
fi

# Check npm
echo -n "Checking npm... "
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    echo -e "${GREEN}✓ Found (npm $NPM_VERSION)${NC}"
else
    echo -e "${YELLOW}⚠ npm should come with Node.js${NC}"
fi

echo ""
echo -e "${GREEN}✅ All dependencies installed!${NC}"
echo ""

# ============================================
# STEP 2: SETUP DATABASE
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗄️  STEP 2: Database Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Set password for postgres user
echo "Setting password for postgres user..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$DB_PASSWORD';" 2>/dev/null

# Check if database already exists
echo -n "Checking database '$DB_NAME'... "
if sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo -e "${GREEN}✓ Already exists${NC}"
    echo "   Note: Using existing database (data will be preserved)"
else
    echo -e "${YELLOW}✗ Not found${NC}"
    echo -n "Creating database '$DB_NAME'... "
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        echo "   Note: Tables will be created by Spring JPA on first startup"
    else
        echo -e "${RED}✗ Failed${NC}"
        exit 1
    fi
fi

# Test connection
echo -n "Testing database connection... "
PGPASSWORD=$DB_PASSWORD psql -U $DB_USER -h localhost -d $DB_NAME -c "SELECT 1;" &>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
    echo "Note: You may need to configure pg_hba.conf"
fi

echo ""
echo -e "${GREEN}✅ Database setup completed!${NC}"
echo ""

# ============================================
# STEP 3: APPLICATION CONFIGURATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  STEP 3: Application Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Setup application.properties
APP_PROP="app/backend/src/main/resources/application.properties"
APP_PROP_EXAMPLE="app/backend/src/main/resources/application.properties.example"

if [ ! -f "$APP_PROP" ]; then
    if [ -f "$APP_PROP_EXAMPLE" ]; then
        echo -n "Creating application.properties... "
        cp "$APP_PROP_EXAMPLE" "$APP_PROP"
        
        # Update credentials (use | delimiter to handle special chars in password)
        sed -i.bak "s|your_database_name|$DB_NAME|g" "$APP_PROP"
        sed -i.bak "s|your_username|$DB_USER|g" "$APP_PROP"
        sed -i.bak "s|your_password|$DB_PASSWORD|g" "$APP_PROP"
        rm -f "$APP_PROP.bak"
        
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ application.properties.example not found${NC}"
    fi
else
    echo -e "${GREEN}✓ application.properties exists${NC}"
fi

# Install frontend dependencies
if [ -d "app/frontend" ]; then
    echo -n "Installing frontend dependencies... "
    cd app/frontend
    npm install --silent &>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ Run 'npm install' manually in app/frontend${NC}"
    fi
    cd "$PHASE1_ROOT"
fi

echo ""
echo -e "${GREEN}✅ Configuration completed!${NC}"
echo ""

# ============================================
# STEP 4: BUILD APPLICATIONS (Production Artifacts)
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  STEP 4: Building Applications"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check directories
if [ ! -d "app/backend" ]; then
    echo -e "${RED}Error: app/backend directory not found${NC}"
    exit 1
fi

if [ ! -d "app/frontend" ]; then
    echo -e "${RED}Error: app/frontend directory not found${NC}"
    exit 1
fi

# --- BUILD BACKEND (Create JAR file) ---
echo -e "${BLUE}🔨 Building Backend (.jar file)...${NC}"
cd app/backend

if [ ! -f "pom.xml" ]; then
    echo -e "${RED}Error: pom.xml not found${NC}"
    exit 1
fi

echo "Running: mvn clean package -DskipTests"
mvn clean package -DskipTests

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backend built successfully!${NC}"
    
    # Find the generated JAR file
    JAR_FILE=$(find target -name "*.jar" ! -name "*-original.jar" | head -n 1)
    if [ -n "$JAR_FILE" ]; then
        echo "   JAR file: $PHASE1_ROOT/app/backend/$JAR_FILE"
    fi
else
    echo -e "${RED}❌ Backend build failed!${NC}"
    exit 1
fi

cd "$PHASE1_ROOT"
echo ""

# --- BUILD FRONTEND (Create static files) ---
echo -e "${BLUE}🔨 Building Frontend (Static files for Nginx)...${NC}"
cd app/frontend

if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: package.json not found${NC}"
    exit 1
fi

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies first...${NC}"
    npm install
fi

echo "Running: npm run build"
npm run build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Frontend built successfully!${NC}"
    echo "   Build directory: $PHASE1_ROOT/app/frontend/build"
else
    echo -e "${RED}❌ Frontend build failed!${NC}"
    exit 1
fi

cd "$PHASE1_ROOT"
echo ""

# ============================================
# STEP 5: CONFIGURE SERVICES (Systemd + Nginx)
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  STEP 5: Configuring Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get project root (go up to Devops_Midterm from phase1)
PROJECT_ROOT="$(cd "$PHASE1_ROOT/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/phase2/configs"

if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "${YELLOW}⚠ Warning: Config directory not found at $CONFIG_DIR${NC}"
    echo "   Skipping service configuration..."
else
    # 1. Configure Backend Service
    echo -n "Configuring backend systemd service... "
    if [ -f "$CONFIG_DIR/backend.service" ]; then
        # Replace environment variables in template
        sed "s|\${USER}|$USER|g; s|\${PROJECT_ROOT}|$PROJECT_ROOT|g" "$CONFIG_DIR/backend.service" | \
            sudo tee /etc/systemd/system/backend.service > /dev/null
        
        sudo systemctl daemon-reload
        sudo systemctl enable backend.service
        sudo systemctl start backend.service
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}✗ backend.service not found${NC}"
    fi

    # 2. Configure Nginx
    echo -n "Configuring Nginx reverse proxy... "
    if [ -f "$CONFIG_DIR/nginx.conf" ]; then
        # Remove default config
        sudo rm -f /etc/nginx/sites-enabled/default
        
        # Replace environment variables in template and copy
        sed "s|\${PROJECT_ROOT}|$PROJECT_ROOT|g" "$CONFIG_DIR/nginx.conf" | \
            sudo tee /etc/nginx/sites-available/notes-app > /dev/null
        
        sudo ln -sf /etc/nginx/sites-available/notes-app /etc/nginx/sites-enabled/
        
        # Test and reload
        if sudo nginx -t &>/dev/null; then
            sudo systemctl reload nginx
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Nginx config test failed${NC}"
        fi
    else
        echo -e "${YELLOW}✗ nginx.conf not found${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Service configuration completed!${NC}"
fi

echo ""

# ============================================
# STEP 6: FIX PERMISSIONS (Critical for Nginx)
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 STEP 6: Fixing File Permissions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fix ownership (in case script was run with sudo)
echo -n "Setting correct ownership... "
sudo chown -R $USER:$USER "$PROJECT_ROOT"
echo -e "${GREEN}✓${NC}"

# Fix home directory permissions for Nginx access
echo -n "Granting Nginx read permissions... "
sudo chmod 755 /home/$USER
sudo chmod 755 "$PROJECT_ROOT"
sudo chmod 755 "$PROJECT_ROOT/phase1"
sudo chmod 755 "$PROJECT_ROOT/phase1/app"
sudo chmod 755 "$PROJECT_ROOT/phase1/app/frontend"
sudo chmod -R 755 "$PROJECT_ROOT/phase1/app/frontend/build"
echo -e "${GREEN}✓${NC}"

echo ""
echo -e "${GREEN}✅ Permissions fixed!${NC}"

echo ""

# ============================================
# STEP 7: Install SSL Certificate Tools
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📦 STEP 7: Install SSL Certificate Tools${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install Certbot for HTTPS setup (manual)
echo -n "Installing Certbot... "
install_package "certbot"
install_package "python3-certbot-nginx"
echo -e "${GREEN}✓${NC}"

echo ""
echo -e "${GREEN}✅ Certbot installed!${NC}"
echo -e "${YELLOW}⚠ NOTE: Domain and HTTPS setup must be done manually${NC}"
echo -e "${YELLOW}   See README.md for configuration instructions${NC}"

echo ""

# ============================================
# DEPLOYMENT COMPLETED
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ SETUP & BUILD COMPLETED!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}📦 Build Artifacts Created:${NC}"
echo "   Backend JAR:  $PHASE1_ROOT/app/backend/target/*.jar"
echo "   Frontend:     $PHASE1_ROOT/app/frontend/build/"
echo ""
echo -e "${BLUE}🔧 Services Configured:${NC}"
echo "   Backend Service: systemctl status backend"
echo "   Nginx:           systemctl status nginx"
echo ""
echo -e "${BLUE}📝 Database Info:${NC}"
echo "   URL:  jdbc:postgresql://localhost:5432/$DB_NAME"
echo "   User: $DB_USER"
echo ""
echo -e "${GREEN}✨ Application is ready and running!${NC}"
echo -e "${BLUE}🌐 Access your app at: http://$(curl -s ifconfig.me)${NC}"
echo ""
