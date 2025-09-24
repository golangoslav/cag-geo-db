FROM postgis/postgis:16-3.4

# Install required tools
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy initialization script and migrations
COPY init.sql /docker-entrypoint-initdb.d/
COPY migrations /docker-entrypoint-initdb.d/migrations

# Copy Vault entrypoint script
COPY scripts/vault-entrypoint.sh /vault-entrypoint.sh
RUN chmod +x /vault-entrypoint.sh

# Expose PostgreSQL port
EXPOSE 5432

# Use custom entrypoint for Vault integration
ENTRYPOINT ["/vault-entrypoint.sh"]
CMD ["postgres"]