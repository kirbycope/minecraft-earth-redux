#!/usr/bin/env bash
# First-boot bootstrap for the Minecraft Earth Solace server (Ubuntu 24.04 arm64).
# Rendered by Terraform templatefile. Shell variables are written without braces; the braced forms are Terraform inputs.
set -euxo pipefail
exec > >(tee /var/log/mce-bootstrap.log) 2>&1

PUBLIC_IP="${public_ip}"
API_PORT="${api_port}"
SOLACE_COMMIT="${solace_commit}"
RESOURCEPACK_URL="${resourcepack_url}"
TILES_ENABLED="${tiles_enabled}"
OSM_URL="${osm_extract_url}"
OSM_BBOX="${osm_bbox}"
IDLE_MIN="${idle_stop_minutes}"

MCE=/opt/mce
APP_USER=ubuntu
export DEBIAN_FRONTEND=noninteractive

# --- system packages ---------------------------------------------------------------------
apt-get update
apt-get install -y git curl unzip jq libicu74 openjdk-17-jre-headless \
  postgresql postgresql-postgis osm2pgsql
# Ubuntu 24.04 ships awscli only as a snap, so use Amazon's installer (the idle-stop cron needs it)
curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o /tmp/awscliv2.zip
unzip -q -o /tmp/awscliv2.zip -d /tmp/awscliv2 && /tmp/awscliv2/aws/install --update >/dev/null && rm -rf /tmp/awscliv2 /tmp/awscliv2.zip

# --- .NET 10 (framework-dependent build needs the runtime+SDK) and PowerShell (publish.ps1) ---
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
bash /tmp/dotnet-install.sh --channel 10.0 --install-dir /opt/dotnet
ln -sf /opt/dotnet/dotnet /usr/local/bin/dotnet
cat > /etc/profile.d/dotnet.sh <<'PROFILE'
export DOTNET_ROOT=/opt/dotnet
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export PATH=$PATH:/opt/dotnet:/opt/dotnet/tools
PROFILE
export DOTNET_ROOT=/opt/dotnet DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_CLI_HOME=/opt/dotnet
dotnet tool install --tool-path /opt/dotnet/tools PowerShell
ln -sf /opt/dotnet/tools/pwsh /usr/local/bin/pwsh

# --- Solace: clone pinned commit and build for linux-arm64 ------------------------------------
install -d -o $APP_USER -g $APP_USER $MCE
sudo -u $APP_USER git clone https://github.com/Earth-Restored/Solace.git $MCE/solace
sudo -u $APP_USER git -C $MCE/solace checkout -q "$SOLACE_COMMIT"
sudo -u $APP_USER env DOTNET_ROOT=/opt/dotnet DOTNET_CLI_TELEMETRY_OPTOUT=1 PATH=$PATH:/opt/dotnet \
  bash -c "cd $MCE/solace && pwsh ./publish.ps1 -profiles framework-dependent-linux-arm64"
BUILD=$MCE/solace/build/Release/framework-dependent-linux-arm64
chmod +x $BUILD/launcher/Launcher $BUILD/components/* || true

# --- one-time game server setup: EULA, event-bus seed, resource pack ------------------------
SD=$BUILD/staticdata
sudo -u $APP_USER sed -i 's/^eula=false/eula=true/' $SD/server_template_dir/eula.txt 2>/dev/null || \
  echo 'eula=true' | sudo -u $APP_USER tee $SD/server_template_dir/eula.txt
grep -q '^vienna-event-bus-queue-name=.\+' $SD/server_template_dir/server.properties 2>/dev/null || \
  cat >> $SD/server_template_dir/server.properties <<'SEED'
${server_props_seed}
SEED
chown $APP_USER:$APP_USER $SD/server_template_dir/server.properties
sudo -u $APP_USER mkdir -p $SD/resourcepacks
sudo -u $APP_USER curl -L -o $SD/resourcepacks/vanilla.zip "$RESOURCEPACK_URL"

# --- launcher settings: public address and tile source, seeded so no UI clicks are needed ---
TILE_SOURCE=0; TILE_ENABLED=false
if [ "$TILES_ENABLED" = "true" ]; then TILE_SOURCE=1; TILE_ENABLED=true; fi
sudo -u $APP_USER tee $BUILD/launcher/config.json > /dev/null <<CFG
{
  "ApiPort": $API_PORT,
  "EventBusPort": 5532,
  "ObjectStorePort": 5396,
  "IPv4": "$PUBLIC_IP",
  "EarthDatabaseConnectionString": "../data/earth.db",
  "LiveDatabaseConnectionString": "../data/live.db",
  "EnableTileRenderingLabel": $TILE_ENABLED,
  "TileDataSource": $TILE_SOURCE,
  "TileDatabaseConnectionString": "Host=localhost;Port=5432;Username=genoa;Password=genoa;Database=genoa_tile_data",
  "GeneratePreviewOnImport": true,
  "SkipFileChecks": false,
  "StaticDataPath": "../staticdata",
  "LauncherBuildplatePreview": false,
  "OnlyAllowLocalLogin": false,
  "BuildplateBasePort": 19132
}
CFG

# --- tiles: PostGIS database + OpenStreetMap import, limited to the play-area bbox ----------
if [ "$TILES_ENABLED" = "true" ]; then
  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='genoa'" | grep -q 1 || sudo -u postgres createuser -s genoa
  sudo -u postgres psql -c "ALTER ROLE genoa WITH PASSWORD 'genoa';"
  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='genoa_tile_data'" | grep -q 1 || sudo -u postgres createdb -O genoa genoa_tile_data
  sudo -u postgres psql -d genoa_tile_data -c "CREATE EXTENSION IF NOT EXISTS postgis;"
  # run the import in the background so the server comes up without waiting on the download
  nohup bash -c "cd /tmp && curl -L -o extract.osm.pbf '$OSM_URL' && \
    PGPASSWORD=genoa osm2pgsql --output=pgsql --bbox='$OSM_BBOX' --style /usr/share/osm2pgsql/default.style \
      -d genoa_tile_data -U genoa -H localhost -P 5432 extract.osm.pbf && rm -f extract.osm.pbf" \
    > /var/log/mce-tiles.log 2>&1 &
fi

# --- run the launcher as a service; --start-on-startup brings every component up on boot ------
cat > /etc/systemd/system/solace.service <<UNIT
[Unit]
Description=Minecraft Earth Solace server
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
User=$APP_USER
WorkingDirectory=$BUILD/launcher
Environment=DOTNET_ROOT=/opt/dotnet
Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
Environment=PATH=/usr/lib/jvm/java-17-openjdk-arm64/bin:/opt/dotnet:/usr/local/bin:/usr/bin:/bin
ExecStart=$BUILD/launcher/Launcher --start-on-startup
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now solace

# --- stop when idle so the wake-on-launch design keeps the bill near zero --------------------
cat > /usr/local/bin/idle-stop.sh <<'IDLE'
${idle_stop_script}
IDLE
chmod +x /usr/local/bin/idle-stop.sh
echo "*/5 * * * * root API_PORT=$API_PORT IDLE_MIN=$IDLE_MIN /usr/local/bin/idle-stop.sh" > /etc/cron.d/mce-idle-stop
chmod 644 /etc/cron.d/mce-idle-stop

echo "bootstrap complete"
