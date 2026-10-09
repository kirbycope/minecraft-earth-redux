#!/usr/bin/env bash
# Create the PostGIS database Solace's tile renderer reads. Idempotent.
# Debian/Ubuntu: apt install postgresql postgresql-postgis osm2pgsql
# macOS: brew install postgresql@17 postgis osm2pgsql   (postgis is NOT built for postgresql@16)
set -euo pipefail
DB="${TILE_DB:-genoa_tile_data}"; USER="${TILE_USER:-genoa}"; PASS="${TILE_PASS:-genoa}"
psql -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='$USER'" | grep -q 1 || createuser -s "$USER"
psql -d postgres -c "ALTER ROLE $USER WITH PASSWORD '$PASS';"
psql -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='$DB'" | grep -q 1 || createdb -O "$USER" "$DB"
psql -d "$DB" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -d "$DB" -tc "SELECT postgis_version();"
echo "connection string for Solace: Host=localhost;Port=5432;Username=$USER;Password=$PASS;Database=$DB"
