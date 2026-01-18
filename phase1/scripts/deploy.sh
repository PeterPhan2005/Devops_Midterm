#!/bin/bash

# ============================================
# AUTO NAVIGATION TO PHASE1 DIRECTORY
# ============================================
# Get script directory (phase1/scripts/), then go back 1 level to phase1/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE1_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Notes Application - Complete Deployment"
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

# Database Configuration (read from environment or use defaults)
DB_NAME="${DB_NAME:-notes_app_db}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres123}"

echo "⚙️  Configuration:"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo ""

# ============================================
# STEP 1: CHECK AND INSTALL PREREQUISITES
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 STEP 1: Checking Prerequisites"
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
    echo "Installing $package..."
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        sudo apt update && sudo apt install -y $package
    elif [ "$PKG_MANAGER" == "yum" ]; then
        sudo yum install -y $package
    elif [ "$PKG_MANAGER" == "brew" ]; then
        brew install $package
    fi
}

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

# Check PostgreSQL
echo -n "Checking PostgreSQL... "
if command -v psql &> /dev/null; then
    PG_VERSION=$(psql --version | awk '{print $3}')
    echo -e "${GREEN}✓ Found (PostgreSQL $PG_VERSION)${NC}"
else
    echo -e "${YELLOW}✗ Not found${NC}"
    if [ "$PKG_MANAGER" == "apt" ]; then
        install_package "postgresql postgresql-contrib"
    elif [ "$PKG_MANAGER" == "yum" ]; then
        install_package "postgresql-server postgresql-contrib"
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
echo -e "${GREEN}✅ All prerequisites checked!${NC}"
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
        
        # Update credentials
        sed -i.bak "s/your_database_name/$DB_NAME/g" "$APP_PROP"
        sed -i.bak "s/your_username/$DB_USER/g" "$APP_PROP"
        sed -i.bak "s/your_password/$DB_PASSWORD/g" "$APP_PROP"
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
# STEP 4: START APPLICATION
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 STEP 4: Starting Application"
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

# Start Backend
echo -e "${BLUE}📦 Starting Backend (Spring Boot)...${NC}"
cd app/backend

if [ ! -f "pom.xml" ]; then
    echo -e "${RED}Error: pom.xml not found${NC}"
    exit 1
fi

echo "Running: mvn spring-boot:run"
mvn spring-boot:run > "$PHASE1_ROOT/backend.log" 2>&1 &
BACKEND_PID=$!

echo -e "Backend PID: ${GREEN}$BACKEND_PID${NC}"
echo "Backend logs: $PHASE1_ROOT/backend.log"

# Wait for backend
echo -n "Waiting for backend to start"
MAX_WAIT=60
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1 || curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
    COUNTER=$((COUNTER+2))
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    echo -e " ${YELLOW}⚠${NC}"
    echo -e "${YELLOW}Backend may still be starting. Check backend.log${NC}"
fi

cd "$PHASE1_ROOT"
echo ""

# Start Frontend
echo -e "${BLUE}🎨 Starting Frontend (React)...${NC}"
cd app/frontend

if [ ! -f "package.json" ]; then
    echo -e "${RED}Error: package.json not found${NC}"
    exit 1
fi

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

echo "Running: npm start"
BROWSER=none npm start > "$PHASE1_ROOT/frontend.log" 2>&1 &
FRONTEND_PID=$!

echo -e "Frontend PID: ${GREEN}$FRONTEND_PID${NC}"
echo "Frontend logs: $PHASE1_ROOT/frontend.log"

cd "$PHASE1_ROOT"
echo ""

# ============================================
# DEPLOYMENT COMPLETED
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETED!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🌐 Access URLs:${NC}"
echo -e "   Frontend: ${GREEN}http://localhost:3000${NC}"
echo -e "   Backend:  ${GREEN}http://localhost:8080${NC}"
echo ""
echo -e "${BLUE}📝 Process IDs:${NC}"
echo "   Backend:  $BACKEND_PID"
echo "   Frontend: $FRONTEND_PID"
echo ""
echo -e "${BLUE}📄 Logs:${NC}"
echo "   Backend:  tail -f $PHASE1_ROOT/backend.log"
echo "   Frontend: tail -f $PHASE1_ROOT/frontend.log"
echo ""
echo -e "${BLUE}📝 Database:${NC}"
echo "   URL: jdbc:postgresql://localhost:5432/$DB_NAME"
echo "   User: $DB_USER"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}🛑 Stopping application...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if kill -0 $BACKEND_PID 2>/dev/null; then
        echo -n "Stopping backend (PID $BACKEND_PID)... "
        kill $BACKEND_PID 2>/dev/null
        echo -e "${GREEN}✓${NC}"
    fi
    
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        echo -n "Stopping frontend (PID $FRONTEND_PID)... "
        kill $FRONTEND_PID 2>/dev/null
        echo -e "${GREEN}✓${NC}"
    fi
    
    pkill -f "spring-boot:run" 2>/dev/null
    pkill -f "react-scripts start" 2>/dev/null
    
    echo ""
    echo -e "${GREEN}Application stopped successfully!${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

wait
