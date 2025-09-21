#!/bin/bash

# Migration runner script for geo database
# Usage: ./run_migrations.sh [migration_number]
# Example: ./run_migrations.sh 005  # runs only migration 005
# Example: ./run_migrations.sh      # runs all pending migrations

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "../.env" ]; then
    source "../.env"
else
    echo -e "${RED}Error: .env file not found!${NC}"
    exit 1
fi

# Database connection parameters
DB_HOST="localhost"
DB_PORT="5433"
DB_NAME="geo_db"
DB_USER="geo_admin"
DB_PASSWORD="geo_secure_pass_2024"

# Function to run a migration
run_migration() {
    local migration_file=$1
    local migration_name=$(basename "$migration_file")

    echo -e "${YELLOW}Running migration: $migration_name${NC}"

    PGPASSWORD=$DB_PASSWORD psql \
        -h $DB_HOST \
        -p $DB_PORT \
        -U $DB_USER \
        -d $DB_NAME \
        -f "$migration_file" \
        -v ON_ERROR_STOP=1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully applied: $migration_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to apply: $migration_name${NC}"
        return 1
    fi
}

# Main execution
echo -e "${GREEN}=== Geo Database Migration Runner ===${NC}"
echo "Database: $DB_NAME @ $DB_HOST:$DB_PORT"
echo ""

# Check if specific migration number was provided
if [ ! -z "$1" ]; then
    # Run specific migration
    MIGRATION_FILE=$(ls *.sql | grep "^$1" | head -1)

    if [ -z "$MIGRATION_FILE" ]; then
        echo -e "${RED}Error: Migration $1 not found!${NC}"
        exit 1
    fi

    run_migration "$MIGRATION_FILE"
else
    # Run all migrations in order
    echo "Running all migrations in order..."
    echo ""

    for migration_file in $(ls *.sql | grep -v rollback | sort); do
        run_migration "$migration_file"
        echo ""
    done
fi

echo -e "${GREEN}=== Migration process completed ===${NC}"