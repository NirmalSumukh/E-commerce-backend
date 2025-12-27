-- PostgreSQL initialization script for e-commerce platform
-- This script sets up initial database configuration, users, and extensions

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- Text search optimization
CREATE EXTENSION IF NOT EXISTS "btree_gin";    -- Composite indexes
CREATE EXTENSION IF NOT EXISTS "btree_gist";   -- Geometric and temporal indexes
CREATE EXTENSION IF NOT EXISTS "hstore";       -- Key-value store
CREATE EXTENSION IF NOT EXISTS "unaccent";     -- Remove accents from text

-- Set default configuration parameters
ALTER SYSTEM SET timezone = 'Asia/Kolkata';
ALTER SYSTEM SET default_text_search_config = 'pg_catalog.english';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '128MB';
ALTER SYSTEM SET work_mem = '4MB';

-- Performance tuning for production
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM SET min_wal_size = '1GB';

-- Logging configuration
ALTER SYSTEM SET log_destination = 'stderr';
ALTER SYSTEM SET logging_collector = on;
ALTER SYSTEM SET log_directory = 'pg_log';
ALTER SYSTEM SET log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log';
ALTER SYSTEM SET log_rotation_age = '1d';
ALTER SYSTEM SET log_rotation_size = '100MB';
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- Log slow queries (>1s)
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';
ALTER SYSTEM SET log_checkpoints = on;
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_lock_waits = on;
ALTER SYSTEM SET log_statement = 'mod';  -- Log modifications

-- Autovacuum tuning for better performance
ALTER SYSTEM SET autovacuum = on;
ALTER SYSTEM SET autovacuum_max_workers = 4;
ALTER SYSTEM SET autovacuum_naptime = '1min';

-- Create custom functions for common operations

-- Function to update modified timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate URL-friendly slugs
CREATE OR REPLACE FUNCTION generate_slug(text_input TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN lower(
        regexp_replace(
            regexp_replace(
                unaccent(text_input),
                '[^a-zA-Z0-9\s-]', '', 'g'
            ),
            '\s+', '-', 'g'
        )
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate distance between two points (for shipping)
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
    radius DOUBLE PRECISION := 6371; -- Earth's radius in kilometers
    dlat DOUBLE PRECISION;
    dlon DOUBLE PRECISION;
    a DOUBLE PRECISION;
    c DOUBLE PRECISION;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat/2) * sin(dlat/2) +
         cos(radians(lat1)) * cos(radians(lat2)) *
         sin(dlon/2) * sin(dlon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    RETURN radius * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create audit trigger function for tracking changes
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (
            table_name,
            operation,
            new_data,
            changed_by,
            changed_at
        ) VALUES (
            TG_TABLE_NAME,
            'INSERT',
            row_to_json(NEW),
            current_user,
            NOW()
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (
            table_name,
            operation,
            old_data,
            new_data,
            changed_by,
            changed_at
        ) VALUES (
            TG_TABLE_NAME,
            'UPDATE',
            row_to_json(OLD),
            row_to_json(NEW),
            current_user,
            NOW()
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (
            table_name,
            operation,
            old_data,
            changed_by,
            changed_at
        ) VALUES (
            TG_TABLE_NAME,
            'DELETE',
            row_to_json(OLD),
            current_user,
            NOW()
        );
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create audit log table (if needed)
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by TEXT NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create indexes on audit log
CREATE INDEX IF NOT EXISTS idx_audit_log_table_name ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON audit_log(changed_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_operation ON audit_log(operation);

-- Database-specific optimizations for Saleor
-- Note: Saleor creates its own tables, but we can add indexes for better performance

-- Comment for future reference
COMMENT ON DATABASE saleor IS 'Saleor e-commerce backend database';
COMMENT ON DATABASE cms IS 'Wagtail CMS database for blog content';
COMMENT ON DATABASE payment IS 'Payment service database for Razorpay transactions';
COMMENT ON DATABASE shipping IS 'Shipping service database for BlueDart tracking';

-- Create read-only user for analytics (optional)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'analytics_ro') THEN
        CREATE USER analytics_ro WITH PASSWORD 'analytics_readonly_password';
    END IF;
END
$$;
-- Note: The main POSTGRES_USER is automatically granted privileges on created databases.
-- We only need to grant specific privileges to other users, like the read-only one.
-- These grants will be applied to the 'saleor' database by default when this script runs.
GRANT CONNECT ON DATABASE saleor TO analytics_ro; -- Allow connection to the saleor DB
GRANT USAGE ON SCHEMA public TO analytics_ro; -- Allow usage of the public schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_ro; -- Grant read-only on all tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO analytics_ro; -- Grant for future tables

-- Optimize for text search (full-text search indexes will be added by applications)
-- But we can set up the base configuration
CREATE TEXT SEARCH CONFIGURATION IF NOT EXISTS english_stem (COPY = pg_catalog.english);
ALTER TEXT SEARCH CONFIGURATION english_stem
    ALTER MAPPING FOR word, asciiword WITH english_stem;

-- Create helper views for monitoring

-- View for monitoring database size
CREATE OR REPLACE VIEW database_sizes AS
SELECT
    datname AS database_name,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datname IN ('saleor', 'cms', 'payment', 'shipping')
ORDER BY pg_database_size(datname) DESC;

-- View for monitoring table sizes
CREATE OR REPLACE VIEW table_sizes AS
SELECT
    schemaname AS schema_name,
    tablename AS table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS data_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS external_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- View for monitoring active connections
CREATE OR REPLACE VIEW active_connections AS
SELECT
    datname AS database,
    usename AS username,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE datname IS NOT NULL
ORDER BY query_start DESC;

-- View for monitoring slow queries
CREATE OR REPLACE VIEW slow_queries AS
SELECT
    datname AS database,
    usename AS username,
    NOW() - query_start AS duration,
    state,
    LEFT(query, 200) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
    AND query_start < NOW() - INTERVAL '5 seconds'
    AND datname IS NOT NULL
ORDER BY duration DESC;

-- Setup complete notification
DO $$
BEGIN
    RAISE NOTICE 'PostgreSQL initialization completed successfully';
    RAISE NOTICE 'Extensions enabled: uuid-ossp, pg_trgm, btree_gin, btree_gist, hstore, unaccent';
    RAISE NOTICE 'Custom functions created: update_modified_column, generate_slug, calculate_distance';
    RAISE NOTICE 'Monitoring views created: database_sizes, table_sizes, active_connections, slow_queries';
END
$$;
