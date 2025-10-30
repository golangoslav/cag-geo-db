#!/bin/sh
set -e

echo "Starting Geo DB with Vault integration..."

# Check if Vault is configured
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
    echo "ERROR: VAULT_ADDR and VAULT_TOKEN must be set"
    exit 1
fi

echo "Connecting to Vault at $VAULT_ADDR..."

# Fetch credentials and config from Vault
CREDS_RESPONSE=$(curl -k -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/cag/shared/credentials/geo_db")
DB_CONFIG_RESPONSE=$(curl -k -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/secret/data/cag/database/geo_db")

# Check responses
if echo "$CREDS_RESPONSE" | grep -q '"errors"'; then
    echo "ERROR: Failed to fetch credentials from Vault"
    echo "$CREDS_RESPONSE"
    exit 1
fi

if echo "$DB_CONFIG_RESPONSE" | grep -q '"errors"'; then
    echo "ERROR: Failed to fetch database config from Vault"
    echo "$DB_CONFIG_RESPONSE"
    exit 1
fi

# Parse and export credentials
export POSTGRES_USER=$(echo "$CREDS_RESPONSE" | jq -r '.data.data.POSTGRES_USER')
export POSTGRES_PASSWORD=$(echo "$CREDS_RESPONSE" | jq -r '.data.data.POSTGRES_PASSWORD')
export POSTGRES_DB=$(echo "$CREDS_RESPONSE" | jq -r '.data.data.POSTGRES_DB')

# Parse and export database configuration
export PGDATA=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.PGDATA // "/var/lib/postgresql/data/pgdata"')
export POSTGRES_MAX_CONNECTIONS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_MAX_CONNECTIONS // "100"')
export POSTGRES_SHARED_BUFFERS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_SHARED_BUFFERS // "256MB"')
export POSTGRES_EFFECTIVE_CACHE_SIZE=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_EFFECTIVE_CACHE_SIZE // "1GB"')
export POSTGRES_WORK_MEM=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_WORK_MEM // "16MB"')
export POSTGRES_MAINTENANCE_WORK_MEM=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_MAINTENANCE_WORK_MEM // "256MB"')
export POSTGRES_CHECKPOINT_COMPLETION_TARGET=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_CHECKPOINT_COMPLETION_TARGET // "0.9"')
export POSTGRES_WAL_BUFFERS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_WAL_BUFFERS // "16MB"')
export POSTGRES_DEFAULT_STATISTICS_TARGET=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_DEFAULT_STATISTICS_TARGET // "100"')
export POSTGRES_RANDOM_PAGE_COST=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_RANDOM_PAGE_COST // "1.1"')
export POSTGRES_EFFECTIVE_IO_CONCURRENCY=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_EFFECTIVE_IO_CONCURRENCY // "200"')
export POSTGIS_ENABLE_OUTDB_RASTERS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGIS_ENABLE_OUTDB_RASTERS // "1"')
export POSTGIS_GDAL_ENABLED_DRIVERS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGIS_GDAL_ENABLED_DRIVERS // "ENABLE_ALL"')
export POSTGRES_LOG_STATEMENT=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_LOG_STATEMENT // "all"')
export POSTGRES_LOG_DURATION=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_LOG_DURATION // "off"')
export POSTGRES_LOG_MIN_DURATION_STATEMENT=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_LOG_MIN_DURATION_STATEMENT // "1000"')
export POSTGRES_INITDB_ARGS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_INITDB_ARGS // "--encoding=UTF8 --locale=en_US.utf8"')
export POSTGRES_WAL_LEVEL=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_WAL_LEVEL // "replica"')
export POSTGRES_MAX_WAL_SENDERS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_MAX_WAL_SENDERS // "3"')
export POSTGRES_MAX_REPLICATION_SLOTS=$(echo "$DB_CONFIG_RESPONSE" | jq -r '.data.data.POSTGRES_MAX_REPLICATION_SLOTS // "3"')

echo "Environment variables loaded from Vault:"
echo "  POSTGRES_USER=$POSTGRES_USER"
echo "  POSTGRES_DB=$POSTGRES_DB"
echo "  POSTGRES_PASSWORD=***hidden***"
echo "  POSTGRES_MAX_CONNECTIONS=$POSTGRES_MAX_CONNECTIONS"
echo "  POSTGRES_SHARED_BUFFERS=$POSTGRES_SHARED_BUFFERS"
echo "  POSTGIS_ENABLE_OUTDB_RASTERS=$POSTGIS_ENABLE_OUTDB_RASTERS"

# Start PostgreSQL with PostGIS
echo "Starting PostgreSQL with PostGIS..."
exec docker-entrypoint.sh "$@"