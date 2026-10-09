# Map tiles, self-hosted

In Minecraft Earth the ground under your character is a map of your real surroundings. Mojang's tile server is
gone; Solace re-renders the tiles itself from OpenStreetMap data, so the map needs a data source. The two choices
in Solace's Map settings are MapTiler (a commercial service, needs an API key, sees which areas you load) and
PostgreSQL (your own database, no third party). This repo uses PostgreSQL.

Solace's `DatabaseTileDataSource` queries `planet_osm_polygon` and `planet_osm_line` by `ST_TileEnvelope`, which is
exactly what `osm2pgsql`'s default `pgsql` output produces. So the whole pipeline is:

```bash
tiles/setup-postgis.sh
tiles/import-osm.sh https://download.geofabrik.de/north-america/us/washington-latest.osm.pbf -122.9,47.2,-122.0,47.9
```

Then in the launcher, Server Options > Map: Enable Tile Rendering, source PostgreSQL, connection string
`Host=localhost;Port=5432;Username=genoa;Password=genoa;Database=genoa_tile_data`. The Terraform deployment seeds
this automatically.

Pick the bbox around where players actually are. The game sends its GPS to `/locations/<lat>/<lon>`, which is how
the Puget Sound box above was chosen. Outside the box the ground is plain green; gameplay is unaffected.
