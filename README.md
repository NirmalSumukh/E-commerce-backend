# Leemasmart Backend

Saleor-based e-commerce backend for Leemasmart.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     LEEMASMART BACKEND                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────┐    ┌─────────────────┐                    │
│   │   Traefik       │    │   PostgreSQL    │                    │
│   │   (SSL/TLS)     │    │   Database      │                    │
│   └────────┬────────┘    └─────────────────┘                    │
│            │                      ▲                              │
│            ▼                      │                              │
│   ┌─────────────────┐    ┌───────┴─────────┐                    │
│   │   Saleor API    │───▶│   Redis Cache   │                    │
│   │   (GraphQL)     │    └─────────────────┘                    │
│   └────────┬────────┘                                           │
│            │                                                     │
│   ┌────────┴────────┐    ┌─────────────────┐                    │
│   │   Dashboard     │    │  Celery Workers │                    │
│   │   (/dashboard)  │    │  (Background)   │                    │
│   └─────────────────┘    └─────────────────┘                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Git

### Local Development

```bash
# Clone the repository
git clone https://github.com/yourusername/leemasmart-backend.git
cd leemasmart-backend

# Copy environment file
cp .env.example .env

# Edit .env with your settings
# For local dev, you can use the defaults

# Start services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# View logs
docker-compose logs -f
```

### Production Deployment (Hostinger VPS)

```bash
# On your VPS, run the setup script
curl -sSL https://raw.githubusercontent.com/yourusername/leemasmart-backend/main/scripts/setup-server.sh | sudo bash

# Edit environment file
nano /opt/leemasmart/.env

# Deploy
./scripts/deploy.sh
```

## 📁 Project Structure

```
.
├── docker-compose.yml          # Base Docker configuration
├── docker-compose.dev.yml      # Development overrides
├── docker-compose.prod.yml     # Production with Traefik SSL
├── Dockerfile                  # Multi-stage build
├── .env.example                # Environment template
├── docker/
│   ├── nginx/                  # Nginx configuration
│   └── postgres/               # Database init scripts
├── scripts/
│   ├── deploy.sh               # Production deployment
│   ├── setup-server.sh         # Initial server setup
│   └── wait-for-it.sh          # Database wait script
└── services/
    ├── saleor/                 # Saleor API
    └── dashboard/              # Saleor Dashboard
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your API domain | `saleor.leemasmart.com` |
| `FRONTEND_DOMAIN` | Frontend domain (for CORS) | `leemasmart.com` |
| `SECRET_KEY` | Django secret key | Random 50+ chars |
| `DB_PASSWORD` | Database password | Strong password |
| `ACME_EMAIL` | Let's Encrypt email | `info@leemasmart.com` |

See `.env.example` for all options.

### CORS Configuration

CORS is automatically configured based on `FRONTEND_DOMAIN`. For local development, `localhost:3000` and `localhost:3001` are allowed by default.

## 🌐 URLs

| Environment | API | Dashboard |
|-------------|-----|-----------|
| **Production** | `https://saleor.leemasmart.com/graphql/` | `https://saleor.leemasmart.com/dashboard/` |
| **Development** | `http://localhost:8000/graphql/` | `http://localhost:9001/dashboard/` |

## 🔄 Deployment Commands

```bash
# Start all services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# View logs
docker-compose logs -f saleor

# Run migrations
docker-compose exec saleor python manage.py migrate

# Create superuser
docker-compose exec saleor python manage.py createsuperuser

# Restart a service
docker-compose restart saleor

# Stop all services
docker-compose down
```

## 🔐 Security Notes

1. **Never commit `.env` files** - They contain secrets
2. **Use strong passwords** - Especially for `DB_PASSWORD` and `SECRET_KEY`
3. **Keep containers updated** - Regularly pull latest images
4. **Use HTTPS** - Traefik handles this automatically in production

## 📝 License

Proprietary - Leemasmart
