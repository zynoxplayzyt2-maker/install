#!/bin/bash

# Ensure the script is run as root (or with sudo)
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[0;31m❌ ERROR: Please run this script with sudo or as root!\033[0m"
  echo -e "\033[0;36m👉 Example: sudo bash install.sh\033[0m"
  exit 1
fi

clear

# Pro-Gaming Sapphire to Violet Gradients & Deep Crimson Red Accents
SAPPHIRE='\033[38;2;15;100;240m'
VIOLET='\033[38;2;130;50;250m'
DEEP_RED='\033[38;2;200;10;40m'
CYN='\033[0;36m'
YEL='\033[1;33m'
GRN='\033[0;32m'
NC='\033[0m' # No Color

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

# 1. System Update and Upgrade Automation
echo -e "${DEEP_RED}[▼] Updating system packages...${NC}"
apt-get update -y && apt-get upgrade -y

echo -e "${DEEP_RED}[▼] Installing Docker & Core Dependencies...${NC}"
apt-get install docker.io docker-compose openssl curl -y

# CodeSandbox/LXC Fix: Detect if systemd is available, otherwise use service
echo -e "${VIOLET}[▼] Booting Docker Daemon (CodeSandbox Compatible)...${NC}"
if pidof systemd &> /dev/null; then
    systemctl enable docker
    systemctl start docker
else
    service docker start
fi

# 2. Setup Directories (Using Local Workspace to fix CodeSandbox /opt permission denied)
INSTALL_DIR="$PWD/pterodactyl_panel"
echo -e "${SAPPHIRE}[▼] Setting up secure Pterodactyl core in ${INSTALL_DIR}...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# Generate Laravel Application Encryption Key
APP_KEY="base64:$(openssl rand -base64 32)"

echo -e "${SAPPHIRE}[▼] Generating system deployment profiles...${NC}"
cat <<EOF > docker-compose.yml
version: '3.8'

x-common:
  database: &db-environment
    MYSQL_PASSWORD: &db-password "PteroSecurePass123!"
    MYSQL_ROOT_PASSWORD: "PteroRootSecurePass123!"
  panel: &panel-environment
    APP_URL: "http://127.0.0.1:8030"
    APP_TIMEZONE: "UTC"
    APP_SERVICE_AUTHOR: "admin@example.com"
    TRUSTED_PROXIES: "*"
    APP_KEY: "${APP_KEY}"
  mail: &mail-environment
    MAIL_FROM: "admin@example.com"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"

services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "./data/database:/var/lib/mysql"
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
      - "8030:80"
      - "4433:443"
    links:
      - database
      - cache
    volumes:
      - "./data/var:/app/var"
      - "./data/nginx:/etc/nginx/http.d"
      - "./data/certs:/etc/letsencrypt"
      - "./data/logs:/app/storage/logs"
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

echo -e "${SAPPHIRE}[▼] Configuring volume nodes & unlocking file paths...${NC}"
mkdir -p ./data/{database,var,nginx,certs,logs}
chmod -R 777 ./data

echo -e "${DEEP_RED}[▼] Booting up Docker Compose containers...${NC}"
docker-compose up -d

echo -e "${VIOLET}[▼] Waiting 30 seconds for CodeSandbox SQL engine to initialize...${NC}"
# Increased sleep time specifically for CodeSandbox performance caps
sleep 30

echo -e "${SAPPHIRE}[▼] Instantiating Database Schema & Migrations...${NC}"
docker-compose exec -T panel php artisan migrate --seed --force

echo -e "${DEEP_RED}[▼] Initializing Master Administrator Creation...${NC}"
echo -e "${YEL}👉 ENTER YOUR PANEL ACCOUNT DETAILS BELOW:${NC}"
# The account prompt will now execute normally because the DB is running
docker-compose exec panel php artisan p:user:make

echo -e "\n-----------------------------------------------------"
echo -e "${VIOLET}██████╗  ██████╗ ███╗   ██╗███████╗██╗██╗${NC}"
echo -e "${SAPPHIRE}██╔══██╗██╔═══██╗████╗  ██║██╔════╝██║██║${NC}"
echo -e "${SAPPHIRE}██║  ██║██║   ██║██╔██╗ ██║█████╗  ██║██║${NC}"
echo -e "${VIOLET}██║  ██║██║   ██║██║╚██╗██║██╔══╝  ╚═╝╚═╝${NC}"
echo -e "${DEEP_RED}██████╔╝╚██████╔╝██║ ╚████║███████╗██╗██╗${NC}"
echo -e "${DEEP_RED}╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝╚═╝${NC}"
echo -e "-----------------------------------------------------"
echo -e "${GRN}✅ Core build and installation completely active!${NC}"
echo -e "${CYN}🌐 Since you are in CodeSandbox, check your 'Ports' tab in the editor.${NC}"
echo -e "${CYN}👉 Click the 'Open in Browser' icon next to Port 8030 to view your panel.${NC}"
echo -e "-----------------------------------------------------\n"
