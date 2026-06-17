#!/bin/bash

clear

# Colors
RED='\033[0;31m'
GRN='\033[0;32m'
CYN='\033[0;36m'
YEL='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YEL}"
cat << "EOF"
 ███████╗ ███████╗ 
██╔════╝ ██╔════╝ 
███████╗ ██║  ███╗
╚════██║ ██║   ██║
███████║ ╚██████╔╝
╚══════╝  ╚═════╝ 
EOF
echo -e "${NC}"

echo -ne "${GRN}🔥 Please Subscribe \n"
for i in {1..3}; do
  echo -ne "${CYN}Subscribing To SanjitGaming"
  for dot in {1..3}; do
    echo -n "."
    sleep 0.3
  done
  echo -ne "\r                     \r"
done
echo -e "${GRN} Thanks for Subscribing! If Not Do It Rn${NC}\n"
sleep 1

echo -e "${YEL}X-> Installing Docker & Docker Compose...${NC}"
apt update
# Installing docker.io ensures the actual docker engine runs, not just the compose plugin
apt install docker.io docker-compose -y
systemctl enable docker
systemctl start docker

echo -e "${CYN}X-> Setting up Pterodactyl Panel directories...${NC}"
mkdir -p /opt/pterodactyl/panel
cd /opt/pterodactyl/panel || exit

# Generate a random 32-character string for the APP_KEY (Required to fix the 500 error)
APP_KEY="base64:$(openssl rand -base64 32)"

echo -e "${CYN}X-> Writing docker-compose.yml...${NC}"
cat <<EOF > docker-compose.yml
version: '3.8'

x-common:
  database: &db-environment
    MYSQL_PASSWORD: &db-password "PteroSecurePass123!"
    MYSQL_ROOT_PASSWORD: "PteroRootSecurePass123!"
  panel: &panel-environment
    APP_URL: "http://127.0.0.1:8030" # You can change this to your domain later in the .env/docker-compose file
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

echo -e "${CYN}X-> Creating data directories and fixing permissions...${NC}"
mkdir -p ./data/{database,var,nginx,certs,logs}
# This fixes the 500 error related to Laravel not being able to write to the log/cache directories
chmod -R 777 ./data

echo -e "${GRN}X-> Starting Pterodactyl containers...${NC}"
docker-compose up -d

echo -e "${YEL}X-> Waiting 20 seconds for database to fully boot...${NC}"
sleep 20

echo -e "${CYN}X-> Running Database Migrations (Fixes 500 Error)...${NC}"
docker-compose exec -T panel php artisan migrate --seed --force

echo -e "${GRN}X-> Creating Admin User...${NC}"
echo -e "${YEL}*** PLEASE FOLLOW THE PROMPTS ON SCREEN TO SET YOUR LOGIN DETAILS ***${NC}"
docker-compose exec panel php artisan p:user:make

echo -e "${YEL}✅ Installation 100% Complete!${NC}"
echo -e "${CYN}🌐 Access your panel via your web browser at: http://YOUR_SERVER_IP:8030${NC}"
