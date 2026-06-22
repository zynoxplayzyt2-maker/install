#!/usr/bin/env bash

# ==============================================================================
# BASH STRICT MODE
# Ensures the script fails fast if any background execution throws an error.
# ==============================================================================
set -euo pipefail

# ==============================================================================
# COLOR PALETTE & STYLING (Pro-Gaming Theme)
# ==============================================================================
SAPPHIRE='\033[38;2;15;100;240m'
VIOLET='\033[38;2;130;50;250m'
DEEP_RED='\033[38;2;200;10;40m'
CYN='\033[0;36m'
YEL='\033[1;33m'
GRN='\033[0;32m'
NC='\033[0m' # No Color

# ==============================================================================
# ADVANCED LOGGING FUNCTIONS
# ==============================================================================
log_info()    { echo -e "${SAPPHIRE}[INFO]${NC} $1"; }
log_success() { echo -e "${GRN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YEL}[WARNING]${NC} $1"; }
log_error()   { echo -e "${DEEP_RED}[ERROR]${NC} $1"; exit 1; }

# Clear terminal screen
clear

# ==============================================================================
# ROOT PRIVILEGE CHECK
# ==============================================================================
if [[ "${EUID}" -ne 0 ]]; then
  log_error "Insufficient permissions. Please run this script with sudo or as root!"
fi

# ==============================================================================
# ASCII ART & BRANDING ANIMATION
# ==============================================================================
echo -e "${VIOLET}"
cat << "EOF"
███████╗██████╗ ██╗   ██╗████████╗
╚══███╔╝██╔══██╗╚██╗ ██╔╝╚══██╔══╝
  ███╔╝ ██████╔╝ ╚████╔╝    ██║   
 ███╔╝  ██╔═══╝   ╚██╔╝     ██║   
███████╗██║        ██║      ██║   
╚══════╝╚═╝        ╚═╝      ╚═╝   
EOF
echo -e "${NC}"

echo -ne "${SAPPHIRE}🔥 Please Subscribe \n"
for i in {1..3}; do
  echo -ne "${VIOLET}Subscribing To ZynoxPlayzYT"
  for dot in {1..3}; do
    echo -n "."
    sleep 0.3
  done
  echo -ne "\r                            \r"
done
echo -e "${SAPPHIRE} Thanks for Subscribing! If Not Do It Rn${NC}\n"
sleep 1

# ==============================================================================
# COMMAND BLOCK 1: FIRST COMMAND ROOT APT
# ==============================================================================
log_info "Executing Core System Updates..."
export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt upgrade -y
log_success "System dependencies updated successfully."

# ==============================================================================
# STAGE 2: RUNTIME DAEMON VERIFICATION & TTRPC/SHIM PATCH
# Cleans up locked socket communication files and reconfigures Docker to use
# cgroupfs, eliminating the CodeSandbox "unsupported protocol" shim crash.
# ==============================================================================
log_info "Cleaning up stale runtime protocols & fixing TTRPC sockets..."

# Force terminate any misbehaving/locked docker and containerd daemons
systemctl stop docker containerd >/dev/null 2>&1 || true
service docker stop >/dev/null 2>&1 || true
service containerd stop >/dev/null 2>&1 || true

# Purge corrupted sockets that trigger "unsupported protocol" failures
rm -f /var/run/docker.sock
rm -rf /var/run/containerd/*

# Reconfigure daemon engine to use cgroupfs (essential for sandbox environments)
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
EOF
log_success "Docker configuration customized for sandbox constraints."

log_info "Booting repaired Containerd & Docker services..."
if command -v systemctl &> /dev/null && pidof systemd &> /dev/null; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl start containerd >/dev/null 2>&1 || true
    systemctl start docker >/dev/null 2>&1 || true
else
    service containerd start >/dev/null 2>&1 || true
    service docker start >/dev/null 2>&1 || true
fi

# Ensure compose toolkit is ready
if ! command -v docker-compose &> /dev/null; then
    log_error "docker-compose binary execution path could not be found."
fi

# ==============================================================================
# STAGE 3: DIRECTORY DEPLOYMENT (/srv/pterodactyl/)
# ==============================================================================
log_info "Initializing production data storage arrays under /srv/pterodactyl/..."
mkdir -p /srv/pterodactyl/{database,var,nginx,certs,logs}
chmod -R 777 /srv/pterodactyl

# Move into installation root
cd /srv/pterodactyl || log_error "Failed to access workspace path /srv/pterodactyl"

# ==============================================================================
# STAGE 4: WRITE EXPLICIT DOCKER-COMPOSE MANIFEST
# ==============================================================================
log_info "Writing core structure manifest to file..."

# 'version' tag has been removed to eliminate the obsolete configuration warning
cat << 'EOF' > docker-compose.yml
x-common:
  database:
    &db-environment
    # Do not remove the "&db-password" from the end of the line below, it is important
    # for Panel functionality.
    MYSQL_PASSWORD: &db-password "CHANGE_ME"
    MYSQL_ROOT_PASSWORD: "CHANGE_ME_TOO"
  panel:
    &panel-environment
    # This URL should be the URL that your reverse proxy routes to the panel server
    APP_URL: "https://pterodactyl.example.com"
    # A list of valid timezones can be found here: http://php.net/manual/en/timezones.php
    APP_TIMEZONE: "UTC"
    APP_SERVICE_AUTHOR: "noreply@example.com"
    TRUSTED_PROXIES: "*" # Set this to your proxy IP
    # Uncomment the line below and set to a non-empty value if you want to use Let's Encrypt
    # to generate an SSL certificate for the Panel.
    # LE_EMAIL: ""
  mail:
    &mail-environment
    MAIL_FROM: "noreply@example.com"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"
 
#
# ------------------------------------------------------------------------------------------
# DANGER ZONE BELOW
#
# The remainder of this file likely does not need to be changed. Please only make modifications
# below if you understand what you are doing.
#
services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "/srv/pterodactyl/database:/var/lib/mysql"
    environment:
      <<: *db-environment
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"
  cache:
    image: redis:alpine
    restart: always
  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "80:80"
      - "443:443"
    links:
      - database
      - cache
    volumes:
      - "/srv/pterodactyl/var/:/app/var/"
      - "/srv/pterodactyl/nginx/:/etc/nginx/http.d/"
      - "/srv/pterodactyl/certs/:/etc/letsencrypt/"
      - "/srv/pterodactyl/logs/:/app/storage/logs"
    environment:
      <<: [*panel-environment, *mail-environment]
      DB_PASSWORD: *db-password
      APP_ENV: "production"
      APP_ENVIRONMENT_ONLY: "false"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
      DB_HOST: "database"
      DB_PORT: "3306"
networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

log_success "docker-compose.yml configuration successfully saved."

# ==============================================================================
# COMMAND BLOCK 2: RUN FILE DOCKER
# ==============================================================================
log_info "Deploying container virtualization network..."
docker-compose up -d
log_success "Containers initialized dynamically in detached engine mode."

# ==============================================================================
# STAGE 5: INTELLIGENT HARDWARE LIFECYCLE CHECK
# ==============================================================================
log_info "Syncing infrastructure engines... waiting for MariaDB handshakes..."
MAX_TRIES=25
TRIES=0
while ! docker-compose exec -T database mysqladmin ping -h"localhost" --silent &> /dev/null; do
    TRIES=$((TRIES+1))
    if [ $TRIES -eq $MAX_TRIES ]; then
        log_error "Database container storage initialization timed out. Sandbox environment has low resources."
    fi
    echo -ne "${VIOLET}Checking SQL readiness... validation sweep [${TRIES}/${MAX_TRIES}]${NC}\r"
    sleep 2
done
echo -ne "\n"
log_success "Database synchronization verification verified active."

# ==============================================================================
# STAGE 6: CORE APPLICATION SETUP
# ==============================================================================
log_info "Initializing database schema structures..."
docker-compose exec -T panel php artisan key:generate --force
docker-compose exec -T panel php artisan migrate --seed --force
log_success "Database seeding and structure installation finalized."

# ==============================================================================
# COMMAND BLOCK 3: CREATE USER PANEL
# ==============================================================================
set +e
log_info "Transferring thread access to Administrative Setup Console..."
echo -e "${YEL}👉 ENTER YOUR PANEL ACCOUNT DETAILS BELOW:${NC}"
docker-compose run --rm panel php artisan p:user:make
set -e

# ==============================================================================
# ARCHITECTURE COMPLETE CLOSING STATEMENT
# ==============================================================================
echo -e "\n-----------------------------------------------------"
echo -e "${VIOLET}██████╗  ██████╗ ███╗   ██╗███████╗██╗██╗${NC}"
echo -e "${SAPPHIRE}██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║██║${NC}"
echo -e "${SAPPHIRE}██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║██║${NC}"
echo -e "${VIOLET}██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝╚═╝${NC}"
echo -e "${DEEP_RED}██████╔╝╚██████╔╝██║ ╚████║███████╗██╗██╗${NC}"
echo -e "${DEEP_RED}╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝╚═╝${NC}"
echo -e "-----------------------------------------------------"
echo -e "${GRN}✅ Installation process completed successfully!${NC}"
echo -e "${CYN}🌐 Access Path: Your configured proxy domain or host IP interface.${NC}"
echo -e "${CYN}👉 Active Traffic Interfaces mapped on port channels [80] and [443].${NC}"
echo -e "-----------------------------------------------------\n"
