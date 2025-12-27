#!/bin/bash
# ============================================
# LEEMASMART BACKEND - SERVER SETUP SCRIPT
# ============================================
# Run this script on a fresh Hostinger VPS to set up the environment
# Usage: curl -sSL https://raw.githubusercontent.com/yourusername/leemasmart-backend/main/scripts/setup-server.sh | bash

set -e

echo "🖥️  Setting up Leemasmart Backend Server..."
echo "============================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root (sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Updating system packages...${NC}"
apt update && apt upgrade -y

echo -e "${YELLOW}🐳 Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    echo -e "${GREEN}✅ Docker installed${NC}"
else
    echo -e "${GREEN}✅ Docker already installed${NC}"
fi

echo -e "${YELLOW}🐳 Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    apt install -y docker-compose-plugin
    # Also install standalone docker-compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✅ Docker Compose installed${NC}"
else
    echo -e "${GREEN}✅ Docker Compose already installed${NC}"
fi

echo -e "${YELLOW}🔧 Installing additional tools...${NC}"
apt install -y git curl htop vim ufw

echo -e "${YELLOW}🔒 Configuring firewall...${NC}"
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
echo -e "${GREEN}✅ Firewall configured (SSH, HTTP, HTTPS allowed)${NC}"

echo -e "${YELLOW}📂 Creating application directory...${NC}"
APP_DIR="/opt/leemasmart"
mkdir -p $APP_DIR
cd $APP_DIR

echo -e "${YELLOW}📥 Cloning repository...${NC}"
if [ -d ".git" ]; then
    echo "Repository already exists, pulling latest..."
    git pull origin main
else
    read -p "Enter your GitHub repository URL: " REPO_URL
    git clone $REPO_URL .
fi

echo -e "${YELLOW}⚙️  Setting up environment...${NC}"
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${YELLOW}⚠️  IMPORTANT: Edit .env file with your actual values!${NC}"
    echo "Run: nano /opt/leemasmart/.env"
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Server setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "1. Edit the .env file: nano /opt/leemasmart/.env"
echo "2. Set your DOMAIN, SECRET_KEY, DB_PASSWORD, and ACME_EMAIL"
echo "3. Start the application: ./scripts/deploy.sh"
echo ""
echo "Useful commands:"
echo "  cd /opt/leemasmart"
echo "  docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d"
echo "  docker-compose logs -f"
echo ""
