FROM postgis/postgis:16-3.4

# Copy initialization script and migrations
COPY init.sql /docker-entrypoint-initdb.d/
COPY migrations /docker-entrypoint-initdb.d/migrations


# Expose PostgreSQL port
EXPOSE 5432

