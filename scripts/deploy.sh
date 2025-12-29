#!/bin/bash
# ============================================
# LEEMASMART BACKEND - DEPLOYMENT SCRIPT
# ============================================
# Run this script to deploy updates to production
# Usage: ./scripts/deploy.sh

set -e

echo "🚀 Starting Leemasmart Backend Deployment..."
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and fill in your values"
    exit 1
fi

# Load environment variables
source .env

echo -e "${YELLOW}📥 Pulling latest changes from Git...${NC}"
git pull origin main

echo -e "${YELLOW}🔨 Building Docker images...${NC}"
docker compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker compose -f docker-compose.yml -f docker-compose.prod.yml down

echo -e "${YELLOW}🚀 Starting containers...${NC}"
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
sleep 10

echo -e "${YELLOW}📊 Running database migrations...${NC}"
docker compose exec -T saleor python manage.py migrate --noinput

echo -e "${YELLOW}📁 Collecting static files...${NC}"
docker compose exec -T saleor python manage.py collectstatic --noinput

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "📊 Check status:  docker compose ps"
echo "📋 View logs:     docker compose logs -f"
echo "🌐 API URL:       https://${DOMAIN}/graphql/"
echo "📊 Dashboard:     https://${DOMAIN}/dashboard/"
echo ""
