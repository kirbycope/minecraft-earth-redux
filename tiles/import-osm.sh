#!/usr/bin/env bash
# Import an OpenStreetMap extract into the tile database, limited to a bounding box.
#
#   tiles/import-osm.sh <extract-url> <bbox>
#   tiles/import-osm.sh https://download.geofabrik.de/north-america/us/washington-latest.osm.pbf -122.9,47.2,-122.0,47.9
#
# bbox is minlon,minlat,maxlon,maxlat. Keep it to a metro area: a whole state in --slim mode writes
# several GB of intermediate tables and filled a 460 GB Mac to zero, which blocks every process that
# writes to disk. Non-slim + bbox keeps only the planet_osm_polygon/planet_osm_line output tables
# that Solace queries (Web Mercator, matching ST_TileEnvelope). A metro import takes under a minute.
set -euo pipefail
url="$1"; bbox="$2"
DB="${TILE_DB:-genoa_tile_data}"; USER="${TILE_USER:-genoa}"; export PGPASSWORD="${TILE_PASS:-genoa}"
style="${OSM_STYLE:-$(dirname "$(dirname "$(command -v osm2pgsql)")")/share/osm2pgsql/default.style}"
[ -f "$style" ] || style=/usr/share/osm2pgsql/default.style
f="$(basename "$url")"
[ -f "$f" ] || curl -L -o "$f" "$url"
osm2pgsql --output=pgsql --bbox="$bbox" --style "$style" -d "$DB" -U "$USER" -H localhost -P 5432 "$f"
psql -U "$USER" -h localhost -d "$DB" -tc "SELECT 'polygons='||count(*) FROM planet_osm_polygon UNION ALL SELECT 'lines='||count(*) FROM planet_osm_line;"
