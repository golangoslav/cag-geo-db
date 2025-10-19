FROM postgis/postgis:16-3.4-alpine

RUN apk add --no-cache curl jq

COPY scripts/vault-entrypoint.sh /vault-entrypoint.sh
RUN chmod +x /vault-entrypoint.sh

COPY ./migrations /docker-entrypoint-initdb.d/migrations

EXPOSE 5432

ENTRYPOINT ["/vault-entrypoint.sh"]
CMD ["postgres"]
