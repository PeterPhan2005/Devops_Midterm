# Notes Application - DevOps Production Deployment

Production-ready full-stack note-taking application with automated setup, Nginx reverse proxy, Systemd services, and SSL/HTTPS support.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Deployment Steps](#deployment-steps)
- [Deployment Notes](#deployment-notes)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

Full-stack Notes Application with CRUD operations and file attachments:

**Features:**
- ✅ Create, read, update, delete notes
- ✅ File upload/download (stored in PostgreSQL BYTEA)
- ✅ **Production deployment with one command**
- ✅ **Nginx reverse proxy** (frontend + API)
- ✅ **Systemd service** (auto-restart backend)
- ✅ **SSL/HTTPS** (Let's Encrypt Certbot)
- ✅ **Secure configuration** (no hardcoded credentials)

**Technologies:**
- Backend: Spring Boot 3.2.1 + Java 21 + PostgreSQL
- Frontend: React 18 + Axios
- Infrastructure: Nginx + Systemd + Certbot
- Deployment: Automated bash script

---

## 🏗️ Architecture

### Production Stack

```
                    Internet
                       │
                       ▼
              ┌──────────────────┐
              │   Let's Encrypt  │ (SSL Certificates)
              │     Certbot      │
              └────────┬─────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────┐
│           Nginx (Port 80/443)                    │
│  ┌─────────────────┐  ┌────────────────────┐    │
│  │  Static Files   │  │  Reverse Proxy     │    │
│  │  (React build)  │  │  /api/ → :8080     │    │
│  └─────────────────┘  └────────────────────┘    │
└──────────────┬─────────────────┬─────────────────┘
               │                 │
        Frontend│                 │Backend API
      (Cached) │                 ▼
               │    ┌──────────────────────────┐
               │    │   Spring Boot Backend    │
               │    │      (Port 8080)         │
               │    │  ┌────────────────────┐  │
               │    │  │ Systemd Service    │  │
               │    │  │ (Auto-restart)     │  │
               │    │  └────────────────────┘  │
               │    └───────────┬──────────────┘
               │                │
               │                ▼
               │    ┌──────────────────────────┐
               └───►│   PostgreSQL Database    │
                    │      (Port 5432)         │
                    │  - Notes table           │
                    │  - File data (BYTEA)     │
                    └──────────────────────────┘
```

### Request Flow

1. **Browser → Nginx (HTTPS):** User visits `https://domain.com`
2. **Nginx → Frontend:** Serves React static files from `build/`
3. **React → Nginx → Backend:** API calls `/api/*` proxied to `:8080/api/*`
4. **Backend → Database:** Spring Boot queries PostgreSQL
5. **Response:** Database → Backend → Nginx → Browser

---

## 🛠️ Tech Stack

- **Backend:** Spring Boot 3.2.1, Java 21, Maven, PostgreSQL
- **Frontend:** React 18, npm, Axios
- **Web Server:** Nginx (reverse proxy + static files)
- **Service Manager:** Systemd (auto-restart)
- **SSL:** Let's Encrypt (Certbot)
- **OS:** Ubuntu 20.04+ (AWS EC2, DigitalOcean, etc.)
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

## 🚀 Deployment Steps

### Prerequisites

- Ubuntu 20.04+ server (AWS EC2, DigitalOcean, etc.)
- Domain name (optional, for HTTPS)
- DNS A record pointing to server IP

### Step 1: Clone Repository

```bash
# SSH to your server
ssh user@your-server-ip

# Clone project
git clone <your-repository-url>
cd Devops_Midterm
```

### Step 2: Choose Deployment Method

You have **two deployment options**:

---

#### **Option A: Traditional Deployment (Phase 1/2)**

**Best for:** Simple setup, direct control, learning traditional Linux deployment

```bash
# Navigate to Phase 1 scripts directory
cd phase1/scripts

# Make script executable
chmod +x setup.sh

# Run setup (will prompt for DB password if needed)
./setup.sh
```

**What happens:**
- ✅ Installs: Java 21, Maven, PostgreSQL, Node.js, Nginx, Certbot
- ✅ Creates database and configures credentials
- ✅ Builds backend JAR file
- ✅ Builds frontend static files
- ✅ Configures Systemd service (auto-restart backend)
- ✅ Configures Nginx (reverse proxy)
- ✅ Sets correct file permissions

**Result:** App running at `http://YOUR_SERVER_IP`

**Architecture:** Backend runs as systemd service, PostgreSQL on host, Nginx serves frontend and proxies API

---

#### **Option B: Docker Deployment (Phase 3)**

**Best for:** Containerization, isolation, modern DevOps practices, easy scaling

**On Server:**
```bash
# Navigate to Phase 3 directory
cd phase3

# Make script executable
chmod +x setup.sh

# Run setup WITHOUT sudo (Script handles permissions automatically)
./setup.sh
```

**Important:**
- ⚠️ **DO NOT run with sudo.** Running with sudo will cause file permission issues.
- The script will prompt for your Docker Hub credentials and Database password.
- **After installation:** You must **Log out and Log back in** (ssh exit & reconnect) for Docker permissions to take effect for your user.

**After script completes, reconnect to server:**
```bash
# Exit current SSH session
exit

# Reconnect to server
ssh user@your-server-ip

# Verify Docker permissions (should see 'docker' in groups)
groups

# Now you can run Docker commands without sudo
cd phase3
docker compose ps
```

**What happens:**
- ✅ Stops Phase 2 services if running (auto-cleanup)
- ✅ Installs: Docker, Docker Compose, Nginx
- ✅ Adds current user to docker group (no sudo needed for docker commands)
- ✅ Pulls Docker image from Docker Hub
- ✅ Starts containers: Backend + PostgreSQL (with docker-compose)
- ✅ Configures Nginx to serve uploads from phase3/uploads/
- ✅ Sets restart policy: containers auto-start on reboot

**Result:** App running at `http://YOUR_SERVER_IP` (containerized)

**Architecture:** Backend and PostgreSQL run in Docker containers, Nginx on host serves static files and proxies to container

**Useful Commands (Phase 3):**
*(Note: If you get "permission denied", log out and log back in first)*

```bash
cd phase3
docker compose ps             # Check container status
docker compose logs -f app    # View backend logs
docker compose logs -f db     # View database logs
docker compose restart        # Restart all containers
docker compose down           # Stop all containers
docker volume ls              # List database volumes
```

---

### Step 3: Configure Domain (Optional)

**Applies to both Phase 1 and Phase 3 deployments.**

If you have a domain name:

```bash
# Update Nginx with your domain
sudo sed -i "s/server_name _;/server_name your-domain.com www.your-domain.com;/g" /etc/nginx/sites-available/notes-app

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### Step 4: Enable HTTPS (Optional)

**Applies to both Phase 1 and Phase 3 deployments.**

```bash
# Run Certbot to get SSL certificate (Sudo is required here)
sudo certbot --nginx

# Follow prompts:
# 1. Enter email address
# 2. Agree to Terms of Service
# 3. Choose: Redirect HTTP to HTTPS (recommended)
```

**Done!** Access your app:
- HTTP: `http://your-domain.com`
- HTTPS: `https://your-domain.com`

---

## 📝 Deployment Notes

### Security

- ✅ **No hardcoded passwords:** All credentials in `.env` file (gitignored)
- ✅ **Secure input:** Password prompt hides characters during setup
- ✅ **Special characters:** Supports passwords with `/`, `@`, `#`, etc.
- ✅ **CORS configured:** Whitelist your domain in `WebConfig.java`

### Multi-Platform Support

- ✅ Works on AWS EC2 (user: ubuntu)
- ✅ Works on DigitalOcean (user: root)
- ✅ Works on any Linux with any username
- ✅ Dynamic user/path detection (no hardcoded paths)

### Service Management

```bash
# Check backend status
sudo systemctl status backend

# Restart backend
sudo systemctl restart backend

# View backend logs
sudo journalctl -u backend -f

# Check Nginx status
sudo systemctl status nginx

# Restart Nginx
sudo systemctl restart nginx

# View Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### File Locations

- Backend JAR: `~/Devops_Midterm/phase1/app/backend/target/notes-backend-1.0.0.jar`
- Frontend build: `~/Devops_Midterm/phase1/app/frontend/build/`
- Nginx config: `/etc/nginx/sites-available/notes-app`
- Systemd service: `/etc/systemd/system/backend.service`
- Environment vars: `~/Devops_Midterm/phase1/scripts/.env`

### Updating Application

```bash
# Pull latest code
cd ~/Devops_Midterm
git pull origin feature/automation-script

# Rebuild backend
cd phase1/app/backend
mvn clean package -DskipTests

# Rebuild frontend
cd ../frontend
npm run build

# Restart backend service
sudo systemctl restart backend

# Verify
sudo systemctl status backend
curl http://localhost:8080/api/notes
```

---

## 🔧 Troubleshooting

### Issue: Backend not starting

```bash
# Check logs
sudo journalctl -u backend -n 50

# Common causes:
# 1. Port 8080 already in use
sudo lsof -i :8080

# 2. Database connection failed
sudo systemctl status postgresql
PGPASSWORD=your_password psql -U postgres -d notes_app_db -c "SELECT 1;"

# 3. JAR file missing
ls -lh ~/Devops_Midterm/phase1/app/backend/target/*.jar
```

### Issue: Nginx 403 Permission Denied

```bash
# Fix directory permissions
sudo chmod 755 /home/$USER
sudo chmod -R 755 ~/Devops_Midterm/phase1/app/frontend/build

# Restart Nginx
sudo systemctl restart nginx
```

### Issue: Certbot failed

```bash
# Check DNS
nslookup your-domain.com

# Check port 80 accessibility
curl -I http://your-domain.com

# Ensure Nginx is running
sudo systemctl status nginx

# Try manual certificate
sudo certbot certonly --nginx -d your-domain.com -d www.your-domain.com
```

### Issue: Can't access via IP after Certbot

After enabling HTTPS, Nginx may block IP access. To allow both:

```bash
sudo sed -i "s/server_name your-domain.com www.your-domain.com;/server_name your-domain.com www.your-domain.com $(curl -s ifconfig.me);/g" /etc/nginx/sites-available/notes-app
sudo nginx -t && sudo systemctl restart nginx
```

---

## 📞 Support

**Documentation:**
- Setup guide: [phase1/scripts/setup.sh](phase1/scripts/setup.sh)
- Domain setup: [DOMAIN_SETUP.md](DOMAIN_SETUP.md)
- Checklist: [PRE_DEPLOYMENT_CHECKLIST.md](PRE_DEPLOYMENT_CHECKLIST.md)

**Useful Commands:**
```bash
# View all services
systemctl list-units --type=service

# Check open ports
sudo netstat -tuln | grep LISTEN

# Test database connection
PGPASSWORD=your_password psql -U postgres -h localhost -d notes_app_db -c "\dt"

# Check Java version
java -version

# Check Nginx config syntax
sudo nginx -t
```

---

## 📄 License

DevOps Midterm Project - Educational Use

---

## 🔄 Version History

- **v1.0.0** - Basic CRUD operations
- **v2.0.0** - Automated deployment script
- **v2.1.0** - Environment variable security (.env)
- **v3.0.0** - Production deployment (Nginx, Systemd, SSL)
  - Multi-platform support (dynamic user/paths)
  - Secure password handling
  - Automated .env creation
  - Template-based config files

---

**Last Updated:** January 19, 2026  
**Status:** ✅ Production Ready