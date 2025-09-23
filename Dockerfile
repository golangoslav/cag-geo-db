FROM postgis/postgis:16-3.4

# Environment variables
ENV POSTGRES_DB=geo_db
ENV POSTGRES_USER=geo_admin
ENV POSTGRES_PASSWORD=geo_secure_pass_2024
ENV PGDATA=/var/lib/postgresql/data/pgdata

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/


# Expose PostgreSQL port
EXPOSE 5432

