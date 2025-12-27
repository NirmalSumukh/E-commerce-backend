# ============================================
# LEEMASMART BACKEND - MAIN DOCKERFILE
# ============================================
# Multi-stage build for production deployment
# This creates a single deployable image containing Saleor + Dashboard

# ==========================================
# Stage 1: Build Saleor Backend Dependencies
# ==========================================
FROM python:3.12-slim AS saleor-builder

WORKDIR /app/saleor

RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    git \
    gettext \
    && rm -rf /var/lib/apt/lists/*

COPY services/saleor/saleor/pyproject.toml .
COPY services/saleor/saleor/requirements*.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt 2>/dev/null || \
    pip install --no-cache-dir .

# ==========================================
# Stage 2: Build Dashboard
# ==========================================
FROM node:20-alpine AS dashboard-builder

WORKDIR /app/dashboard

# Copy package files
COPY services/dashboard/saleor-dashboard/package*.json ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy source files
COPY services/dashboard/saleor-dashboard/ .

# Build arguments for dashboard
ARG API_URL=http://localhost:8000/graphql/
ARG APP_MOUNT_URI=/dashboard/

ENV API_URL=${API_URL}
ENV APP_MOUNT_URI=${APP_MOUNT_URI}

# Build dashboard
RUN npm run build

# ==========================================
# Stage 3: Final Production Image
# ==========================================
FROM python:3.12-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    libmagic1 \
    nginx \
    supervisor \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r saleor && useradd -r -g saleor saleor

# Create app directory structure
RUN mkdir -p /app/saleor /app/dashboard /app/media /app/static /app/nginx \
    && chown -R saleor:saleor /app/

# Copy Python packages from builder
COPY --from=saleor-builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=saleor-builder /usr/local/bin/ /usr/local/bin/

# Copy Saleor source code
COPY services/saleor/saleor /app/saleor

# Copy built dashboard
COPY --from=dashboard-builder /app/dashboard/build /app/dashboard

# Copy nginx configuration
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Copy supervisor configuration
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy startup scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/wait-for-it.sh /wait-for-it.sh
RUN chmod +x /entrypoint.sh /wait-for-it.sh

# Set working directory
WORKDIR /app/saleor

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=saleor.settings

# Collect static files
ARG STATIC_URL=/static/
ENV STATIC_URL=${STATIC_URL}
RUN SECRET_KEY=dummy python manage.py collectstatic --noinput 2>/dev/null || true

# Expose ports
EXPOSE 80 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/graphql/ -X POST -H "Content-Type: application/json" -d '{"query":"{__typename}"}' || exit 1

# Start supervisor to manage all processes
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]