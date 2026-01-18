# Notes Application - DevOps Project

A full-stack note-taking application with file attachment support, built with Spring Boot and React. This project demonstrates modern DevOps practices including automated deployment, containerization, and CI/CD pipelines.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment](#deployment)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Development](#development)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

The Notes Application is a full-stack web application that allows users to:
- ✅ Create, read, update, and delete notes
- ✅ Attach files to notes (stored in PostgreSQL as BLOB)
- ✅ View and download attached files
- ✅ Responsive UI built with React
- ✅ RESTful API backend with Spring Boot
- ✅ Automated deployment scripts

**Key Features:**
- **Backend:** Spring Boot 3.2.1, Spring Data JPA, PostgreSQL
- **Frontend:** React 18, Axios for API calls
- **Database:** PostgreSQL with JPA auto-schema generation
- **DevOps:** Automated deployment, environment-agnostic scripts

---

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Client Browser                      │
│                   (React Frontend)                      │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP/REST API
                     │ (Port 3000)
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  Spring Boot Backend                    │
│                    (Port 8080)                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Controller  │→ │   Service    │→ │  Repository  │  │
│  │   Layer     │  │    Layer     │  │    Layer     │  │
│  └─────────────┘  └──────────────┘  └──────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │ JDBC
                     │ (Port 5432)
                     ▼
┌─────────────────────────────────────────────────────────┐
│              PostgreSQL Database                        │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  notes   │  │  file_data   │  │   metadata      │  │
│  │  table   │  │   (BYTEA)    │  │   (timestamps)  │  │
│  └──────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Component Architecture

**Backend Layers:**
- **Controller:** REST endpoints for note operations
- **Service:** Business logic and file handling
- **Repository:** JPA data access layer
- **Entity:** Note entity with file storage support

**Frontend Structure:**
- **Components:** Reusable UI components
- **Services:** API communication layer
- **State Management:** React hooks for state

### Data Flow

1. User creates/updates note via React UI
2. Frontend sends HTTP request to Backend API
3. Backend validates and processes the request
4. JPA saves data to PostgreSQL (including file as BLOB)
5. Backend returns response to Frontend
6. Frontend updates UI accordingly

---

## 🛠️ Tech Stack

### Backend
- **Framework:** Spring Boot 3.2.1
- **Language:** Java 21
- **Build Tool:** Maven
- **Database:** PostgreSQL
- **ORM:** Spring Data JPA / Hibernate
- **API:** RESTful with Spring Web

### Frontend
- **Framework:** React 18.2.0
- **Build Tool:** Create React App (react-scripts 5.0.1)
- **HTTP Client:** Axios 1.6.2
- **Icons:** React Icons 4.12.0
- **Styling:** CSS3

### Database
- **RDBMS:** PostgreSQL
- **Schema Management:** JPA Auto DDL (hibernate.ddl-auto=update)
- **File Storage:** BYTEA (Binary Large Object)

### DevOps
- **OS Support:** Linux, macOS
- **Deployment:** Automated Bash scripts
- **Package Managers:** apt, yum, brew
- **Version Control:** Git

---

## 📦 Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| Java JDK | 21 | Backend runtime |
| Maven | 3.6+ | Build tool |
| PostgreSQL | 12+ | Database |
| Node.js | 18+ or 20+ (LTS) | Frontend runtime |
| npm | 8+ | Package manager |
| Git | 2.x | Version control |

### System Requirements

- **OS:** Ubuntu 20.04+, macOS 10.15+, or RHEL 8+
- **RAM:** Minimum 4GB
- **Disk Space:** 2GB free space
- **Network:** Internet connection for dependencies

---

## 🚀 Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd Devops_Midterm

# Setup environment variables
cd phase1/scripts
cp .env.example .env
# Edit .env and change DB_PASSWORD to your secure password

# Run automated deployment script
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. ✅ Load environment variables from `.env` file
2. ✅ Check and install all prerequisites (Java 21, Maven, PostgreSQL, Node.js)
3. ✅ Start PostgreSQL service
4. ✅ Create database with credentials from `.env`
5. ✅ Configure application.properties automatically
6. ✅ Install frontend dependencies
7. ✅ Start both backend and frontend

**Access URLs:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:8080
- API Docs: http://localhost:8080/api/notes

### Option 2: Manual Setup

#### 1. Install Prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y openjdk-21-jdk maven postgresql postgresql-contrib nodejs npm

# macOS
brew install openjdk@21 maven postgresql node
```

#### 2. Setup Environment Variables

```bash
# Navigate to scripts directory
cd phase1/scripts

# Copy environment template
cp .env.example .env

# Edit .env file and set your database password
# DB_NAME=notes_app_db
# DB_USER=postgres
# DB_PASSWORD=your_secure_password_here
```

#### 3. Setup Database

```bash
# Start PostgreSQL
sudo systemctl start postgresql  # Linux
brew services start postgresql   # macOS

# The deploy.sh script will automatically:
# - Set postgres user password from .env
# - Create database from .env configuration
```

#### 4. Configure Backend

```bash
# The deploy.sh script will automatically:
# - Copy application.properties.example to application.properties
# - Replace database credentials with values from .env
# No manual configuration needed!
```

#### 5. Start Backend

```bash
cd backend
mvn spring-boot:run
```

Backend will start on http://localhost:8080

#### 6. Start Frontend

```bash
cd frontend
npm install
npm start
```

Frontend will start on http://localhost:3000

---

## 🚢 Deployment

### Environment Variables

**🔐 Security First:** This project uses `.env` file to store sensitive information like database passwords.

#### Setup for First Time

```bash
# Navigate to scripts directory
cd phase1/scripts

# Create .env from example
cp .env.example .env

# Edit .env with your secure credentials
nano .env  # or vim, code, etc.
```

**`.env` file structure:**
```env
# PostgreSQL Database Configuration
DB_NAME=notes_app_db
DB_USER=postgres
DB_PASSWORD=your_secure_password_here  # ⚠️ CHANGE THIS!

# Backend Configuration
BACKEND_PORT=8080

# Frontend Configuration
FRONTEND_PORT=3000
```

#### For Production Deployment

```bash
# Edit .env for production settings
DB_NAME="production_notes_db"
DB_USER="app_user"
DB_PASSWORD="very_secure_password_here"

# Run deployment
./deploy.sh
```

**⚠️ Important:**
- `.env` file is gitignored and will NOT be pushed to repository
- Each developer/server needs their own `.env` file
- Never commit `.env` with real passwords
- Only `.env.example` should be in Git

### Deployment Script Features

The `deploy.sh` script provides:

✅ **Environment Variable Management**
- Loads configuration from `phase1/scripts/.env`
- No hardcoded passwords in code
- Validates .env file exists before proceeding

✅ **Automatic Runtime Installation**
- Detects OS (Linux/macOS)
- Installs Java 21, Maven, PostgreSQL, Node.js
- Configures package managers (apt/yum/brew)

✅ **Database Management**
- Creates database with name from `.env`
- Sets postgres password from `.env`
- Preserves existing data on re-run
- Tests database connectivity

✅ **Configuration Management**
- Auto-generates application.properties from template
- Injects database credentials from `.env`
- Secure: No passwords in application.properties.example

✅ **Process Management**
- Runs backend and frontend in background
- Provides process IDs for management
- Graceful shutdown on Ctrl+C

✅ **Logging**
- Backend logs: `backend.log`
- Frontend logs: `frontend.log`
- Color-coded console output

### Production Considerations

**Security:**
- ✅ Passwords stored in `.env` file (gitignored)
- ✅ No hardcoded secrets in code
- Create strong database password in `.env`
- Configure pg_hba.conf for authentication
- Enable HTTPS for production
- Keep `.env` file permissions restricted: `chmod 600 .env`

**Performance:**
- Adjust JVM heap size for backend
- Configure connection pool settings
- Use production build for frontend: `npm run build`
- Consider load balancer for scaling

**Monitoring:**
- Monitor logs: `tail -f backend.log frontend.log`
- Check process status: `ps aux | grep spring-boot`
- Monitor database connections

---

## 📁 Project Structure

```
Devops_Midterm/
├── phase1/                           # Phase 1: Basic Deployment
│   ├── app/
│   │   ├── backend/                  # Spring Boot Backend
│   │   │   ├── src/
│   │   │   │   └── main/
│   │   │   │       ├── java/com/noteapp/
│   │   │   │       │   ├── NotesApplication.java      # Main application class
│   │   │   │       │   ├── controller/
│   │   │   │       │   │   └── NoteController.java    # REST endpoints
│   │   │   │       │   ├── service/
│   │   │   │       │   │   └── NoteService.java       # Business logic
│   │   │   │       │   ├── repository/
│   │   │   │       │   │   └── NoteRepository.java    # Data access
│   │   │   │       │   ├── entity/
│   │   │   │       │   │   └── Note.java              # JPA entity
│   │   │   │       │   ├── dto/
│   │   │   │       │   │   └── NoteDTO.java           # Data transfer object
│   │   │   │       │   └── config/
│   │   │   │       │       └── WebConfig.java         # CORS configuration
│   │   │   │       └── resources/
│   │   │   │           ├── application.properties.example  # Config template
│   │   │   │           └── application.properties          # Actual config (gitignored)
│   │   │   ├── pom.xml                       # Maven dependencies
│   │   │   └── target/                       # Build output (gitignored)
│   │   │
│   │   └── frontend/                 # React Frontend
│   │       ├── public/
│   │       │   └── index.html
│   │       ├── src/
│   │       │   ├── App.js            # Main component
│   │       │   ├── components/       # Reusable components
│   │       │   └── services/         # API services
│   │       ├── package.json          # npm dependencies
│   │       └── node_modules/         # Dependencies (gitignored)
│   │
│   ├── scripts/
│   │   ├── deploy.sh                 # 🚀 Automated deployment script
│   │   ├── .env                      # 🔐 Environment variables (gitignored)
│   │   └── .env.example              # 📝 Environment template (committed)
│   │
│   ├── SETUP_ENV.md                  # 📖 Environment setup guide
│   ├── backend.log                   # Backend logs (gitignored)
│   └── frontend.log                  # Frontend logs (gitignored)
│
├── phase2/                           # Phase 2: Containerization
│
├── phase3/                           # Phase 3: CI/CD Pipeline
│
├── .gitignore                        # Git ignore rules
├── .gitattributes                    # Git line ending rules
└── README.md                         # This file
```

---

## ⚙️ Configuration

### Backend Configuration

**📝 Note:** Database credentials are now managed via `.env` file, not hardcoded in application.properties.

**application.properties.example (template):**

```properties
# Database Configuration
spring.datasource.url=jdbc:postgresql://localhost:5432/your_database_name
spring.datasource.username=your_username
spring.datasource.password=your_password

# JPA Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

# File Upload Configuration
spring.servlet.multipart.max-file-size=5MB
spring.servlet.multipart.max-request-size=5MB

# Server Configuration
server.port=8080

# CORS Configuration
spring.web.cors.allowed-origins=http://localhost:3000
```

**The `deploy.sh` script automatically:**
- Copies `application.properties.example` to `application.properties`
- Replaces placeholders with actual values from `.env`
- No manual editing needed!

### Frontend Configuration

**Package.json scripts:**

```json
{
  "scripts": {
    "start": "react-scripts start",      // Development server
    "build": "react-scripts build",      // Production build
    "test": "react-scripts test",        // Run tests
    "eject": "react-scripts eject"       // Eject from CRA
  }
}
```

### Environment-Specific Configuration

For different environments (dev/staging/prod), use Spring profiles:

```bash
# Create profile-specific files
application-dev.properties
application-staging.properties
application-prod.properties

# Activate profile
export SPRING_PROFILES_ACTIVE=prod
```

---

## 💻 Development

### Running in Development Mode

**Backend with hot reload:**
```bash
cd backend
mvn spring-boot:run
```

**Frontend with hot reload:**
```bash
cd frontend
npm start
```

### Building for Production

**Backend:**
```bash
cd backend
mvn clean package
java -jar target/notes-backend-1.0.0.jar
```

**Frontend:**
```bash
cd frontend
npm run build
# Serve the build/ directory with a static server
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notes` | Get all notes |
| GET | `/api/notes/{id}` | Get note by ID |
| POST | `/api/notes` | Create new note |
| PUT | `/api/notes/{id}` | Update note |
| DELETE | `/api/notes/{id}` | Delete note |
| GET | `/api/notes/{id}/file` | Download file attachment |

**Example Request:**
```bash
curl -X POST http://localhost:8080/api/notes \
  -F "title=My Note" \
  -F "content=Note content here" \
  -F "file=@/path/to/file.pdf"
```

---

## 🧪 Testing

### Backend Tests

```bash
cd backend
mvn test
```

### Frontend Tests

```bash
cd frontend
npm test
```

### Integration Tests

```bash
# Start both backend and frontend
cd phase1/scripts
./deploy.sh

# Test in browser
open http://localhost:3000
```

---

## 🐛 Troubleshooting

### Common Issues

#### Issue: Port already in use

**Backend (Port 8080):**
```bash
# Find process using port 8080
lsof -i :8080
# or
netstat -anp | grep 8080

# Kill the process
kill -9 <PID>
```

**Frontend (Port 3000):**
```bash
# Find and kill
lsof -i :3000
kill -9 <PID>
```

#### Issue: Database connection failed

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Start if not running
sudo systemctl start postgresql

# Check connection
psql -U postgres -h localhost -c "SELECT 1;"
```

#### Issue: Java version mismatch

```bash
# Check current Java version
java -version

# Install Java 21
sudo apt install openjdk-21-jdk

# Set Java 21 as default
sudo update-alternatives --config java
```

#### Issue: npm install fails

```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

### Viewing Logs

```bash
# Backend logs
tail -f backend.log

# Frontend logs
tail -f frontend.log

# Both logs
tail -f backend.log frontend.log
```

### Database Issues

```bash
# Access PostgreSQL console
sudo -u postgres psql

# List databases
\l

# Connect to notes database
\c notes_app_db

# List tables
\dt

# View table structure
\d notes

# Check data
SELECT * FROM notes;
```

---

## 📞 Support

For issues, questions, or contributions, please:
1. Check existing issues in the repository
2. Review this README and troubleshooting section
3. Create a new issue with detailed information

---

## 📄 License

This project is part of a DevOps course assignment.

---

## 👥 Contributors

- DevOps Team - Mid Term Project

---

## 🔄 Version History

- **v1.0.0** - Initial release with basic CRUD functionality
- **Phase 1** - Automated deployment scripts
- **Phase 2** - (Coming soon) Containerization
- **Phase 3** - (Coming soon) CI/CD Pipeline

---

**Last Updated:** January 2026