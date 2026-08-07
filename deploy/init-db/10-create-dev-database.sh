#!/bin/bash
# Runs once, the first time the postgres volume is initialised.
# Creates the dev database with its own role, so a mistyped DATABASE_URL in the
# dev stack cannot reach production data.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	CREATE ROLE ${DEV_DB_USER} WITH LOGIN PASSWORD '${DEV_DB_PASSWORD}';
	CREATE DATABASE ${DEV_DB_NAME} OWNER ${DEV_DB_USER};
	REVOKE ALL ON DATABASE ${DEV_DB_NAME} FROM PUBLIC;
	REVOKE ALL ON DATABASE ${POSTGRES_DB} FROM ${DEV_DB_USER};
EOSQL
