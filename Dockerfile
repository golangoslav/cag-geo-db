FROM postgis/postgis:16-3.4

# Environment variables
ENV POSTGRES_DB=geo_db
ENV POSTGRES_USER=geo_admin
ENV POSTGRES_PASSWORD=geo_secure_pass_2024
ENV PGDATA=/var/lib/postgresql/data/pgdata

# Copy initialization scripts and migrations
COPY init.sql /docker-entrypoint-initdb.d/
COPY migrations/ /migrations/

# Create backup directory
RUN mkdir -p /backups

# Expose PostgreSQL port
EXPOSE 5432

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
  CMD pg_isready -U geo_admin -d geo_db || exit 1