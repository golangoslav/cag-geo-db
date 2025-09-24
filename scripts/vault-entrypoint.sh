#!/bin/sh
set -e

echo "Starting Geo DB with Vault integration..."

# Vault configuration
VAULT_ADDR="${VAULT_ADDR:-http://cag-vault-turnkey:8200}"
VAULT_TOKEN="${VAULT_SERVICE_TOKEN}"
SECRET_PATH="secret/data/cag/geo-db"

# Check if Vault token is provided
if [ -n "$VAULT_TOKEN" ]; then
    echo "Vault token found, attempting to load secrets from Vault..."

    # Try to fetch secrets from Vault
    RESPONSE=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/$SECRET_PATH")

    # Check if response contains data
    if echo "$RESPONSE" | grep -q '"data"'; then
        echo "Successfully fetched secrets from Vault"

        # Parse JSON and export environment variables
        # Using jq if available, otherwise fallback to simple parsing
        if command -v jq >/dev/null 2>&1; then
            # Extract each secret and export as environment variable
            export POSTGRES_DB=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_DB // empty')
            export POSTGRES_USER=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_USER // empty')
            export POSTGRES_PASSWORD=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_PASSWORD // empty')
            export POSTGRES_PORT=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_PORT // empty')
            export PGDATA=$(echo "$RESPONSE" | jq -r '.data.data.PGDATA // empty')
            export POSTGRES_MAX_CONNECTIONS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_MAX_CONNECTIONS // empty')
            export POSTGRES_SHARED_BUFFERS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_SHARED_BUFFERS // empty')
            export POSTGRES_EFFECTIVE_CACHE_SIZE=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_EFFECTIVE_CACHE_SIZE // empty')
            export POSTGRES_WORK_MEM=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_WORK_MEM // empty')
            export POSTGRES_MAINTENANCE_WORK_MEM=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_MAINTENANCE_WORK_MEM // empty')
            export POSTGRES_CHECKPOINT_COMPLETION_TARGET=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_CHECKPOINT_COMPLETION_TARGET // empty')
            export POSTGRES_WAL_BUFFERS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_WAL_BUFFERS // empty')
            export POSTGRES_DEFAULT_STATISTICS_TARGET=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_DEFAULT_STATISTICS_TARGET // empty')
            export POSTGRES_RANDOM_PAGE_COST=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_RANDOM_PAGE_COST // empty')
            export POSTGRES_EFFECTIVE_IO_CONCURRENCY=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_EFFECTIVE_IO_CONCURRENCY // empty')
            export POSTGIS_ENABLE_OUTDB_RASTERS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGIS_ENABLE_OUTDB_RASTERS // empty')
            export POSTGIS_GDAL_ENABLED_DRIVERS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGIS_GDAL_ENABLED_DRIVERS // empty')
            export POSTGRES_LOG_STATEMENT=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_LOG_STATEMENT // empty')
            export POSTGRES_LOG_DURATION=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_LOG_DURATION // empty')
            export POSTGRES_LOG_MIN_DURATION_STATEMENT=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_LOG_MIN_DURATION_STATEMENT // empty')
            export POSTGRES_INITDB_ARGS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_INITDB_ARGS // empty')
            export POSTGRES_WAL_LEVEL=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_WAL_LEVEL // empty')
            export POSTGRES_MAX_WAL_SENDERS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_MAX_WAL_SENDERS // empty')
            export POSTGRES_MAX_REPLICATION_SLOTS=$(echo "$RESPONSE" | jq -r '.data.data.POSTGRES_MAX_REPLICATION_SLOTS // empty')

            echo "Environment variables set from Vault:"
            echo "  POSTGRES_USER=$POSTGRES_USER"
            echo "  POSTGRES_DB=$POSTGRES_DB"
            echo "  POSTGRES_PASSWORD=***hidden***"
            echo "  POSTGRES_MAX_CONNECTIONS=$POSTGRES_MAX_CONNECTIONS"
            echo "  POSTGIS_ENABLE_OUTDB_RASTERS=$POSTGIS_ENABLE_OUTDB_RASTERS"
        else
            echo "Warning: jq not found, using basic parsing"
            # Fallback to sed/grep parsing if jq is not available
        fi
    else
        echo "Warning: Failed to fetch secrets from Vault"
        echo "Response: $RESPONSE"
        echo "Continuing with environment variables or defaults..."
    fi
else
    echo "No Vault token provided, using environment variables or defaults"
fi

# Start PostgreSQL with PostGIS
echo "Starting PostgreSQL with PostGIS..."
exec docker-entrypoint.sh "$@"