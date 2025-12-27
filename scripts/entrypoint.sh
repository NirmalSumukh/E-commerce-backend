#!/bin/bash
# ============================================
# LEEMASMART BACKEND - ENTRYPOINT SCRIPT
# ============================================
# This script runs when the Docker container starts

set -e

echo "🚀 Starting Leemasmart Backend..."

# Wait for database
if [ -n "$DATABASE_URL" ]; then
    echo "⏳ Waiting for database..."
    /wait-for-it.sh postgres:5432 --timeout=60 --strict -- echo "✅ Database is ready"
fi

# Run migrations
echo "📊 Running database migrations..."
python manage.py migrate --noinput

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Create log directories
mkdir -p /var/log/supervisor /var/log/nginx
chown -R saleor:saleor /app/media /app/static 2>/dev/null || true

# Start supervisor
echo "✅ Starting services..."
exec "$@"
