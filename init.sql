-- PostgreSQL initialization script for geo database
-- Loads all migrations in order

-- Create database if not exists (when POSTGRES_DB != geo_db)
SELECT 'CREATE DATABASE geo_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'geo_db')\gexec

-- Connect to geo_db for further initialization
\c geo_db;

-- Run migrations in order
\i /docker-entrypoint-initdb.d/migrations/001_create_extensions.sql
\i /docker-entrypoint-initdb.d/migrations/002_create_schema.sql
\i /docker-entrypoint-initdb.d/migrations/003_create_office_types_table.sql
\i /docker-entrypoint-initdb.d/migrations/004_create_offices_table.sql
\i /docker-entrypoint-initdb.d/migrations/005_create_indexes.sql
\i /docker-entrypoint-initdb.d/migrations/006_create_update_location_function.sql
\i /docker-entrypoint-initdb.d/migrations/007_create_update_timestamp_function.sql
\i /docker-entrypoint-initdb.d/migrations/008_create_find_nearest_offices_function.sql
\i /docker-entrypoint-initdb.d/migrations/009_insert_office_types.sql
\i /docker-entrypoint-initdb.d/migrations/010_insert_sample_offices.sql
\i /docker-entrypoint-initdb.d/migrations/011_add_table_comments.sql