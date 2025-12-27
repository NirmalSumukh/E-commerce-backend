#!/bin/bash
# scripts/create-multiple-databases.sh
# This script creates multiple databases for different services in production

set -e
set -u

function create_user_and_database() {
    local database=$1
    echo "Creating database '$database' with proper permissions..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        -- Create database if it doesn't exist
        SELECT 'CREATE DATABASE $database'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
        
        -- Grant all privileges to the main user
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
        
        -- Connect to the database and set up extensions
        \c $database
        
        -- Enable useful extensions for production
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS "pg_trgm";
        CREATE EXTENSION IF NOT EXISTS "btree_gin";
        CREATE EXTENSION IF NOT EXISTS "btree_gist";
EOSQL
}

# Parse the POSTGRES_MULTIPLE_DATABASES variable
if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Creating multiple databases: $POSTGRES_MULTIPLE_DATABASES"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database $db
    done
    echo "All databases created successfully!"
fi
echo "Database initialization complete!"