# Server: Solace

[Solace](https://github.com/Earth-Restored/Solace) is the maintained replacement server for Minecraft Earth, based on
micheal65536's Vienna. It implements the game API and, crucially, emulates Microsoft login, Xbox Live and PlayFab with
its own account system, which is what makes sign-in possible after Microsoft retired the game's Xbox title.
Pinned commit: `UPSTREAM_COMMIT`.

Six components run under a launcher with a web admin UI: Event Bus, Object Store, API Server (port 8080, what the
game talks to), Buildplate Launcher (spawns a Fabric Minecraft 1.20.4 server per active buildplate, UDP 19132+),
Tappables Generator, Tile Renderer.

## First-run checklist (what the AWS user-data automates)

1. Build: `pwsh publish.ps1 -profiles framework-dependent-<os>-<arch>` (needs .NET 10, PowerShell, Java 17).
2. `staticdata/server_template_dir/eula.txt`: `eula=true`.
3. Append `server.properties.seed` to `staticdata/server_template_dir/server.properties`.
4. Put the game resource pack at `staticdata/resourcepacks/vanilla.zip` (contains `genoa.mcpack`; community
   archive: andiricum2/MC-Earth-Resourcepack release v1).
5. `launcher/config.json`: set `IPv4` to the address players reach, and the tile settings (see `tiles/`).
6. Run `launcher/Launcher --start-on-startup` (see Terraform `user-data.sh.tpl` for the systemd unit).
7. Open the launcher UI (`localhost:5050`, on macOS AirPlay holds 5000 so the Kestrel port is changed), register
   the first account (it becomes owner), then confirm it: with no mail server the link is on the confirmation
   page, or `sqlite3 launcher/Data/app.db "UPDATE AspNetUsers SET EmailConfirmed=1"`.

## Two account systems

The launcher admin account (ASP.NET Identity, `launcher/Data/app.db`) manages the server. The in-game player
account lives in the API's `earth.db` and is created from the game's own Register tab (username: lowercase,
digits, underscore, colon). Linked Accounts in the launcher links an existing game account; it does not create one.
Do not rename the admin username through the Edit dialog: its prefilled reset-password field silently changed the
password. If that happens, stop everything, delete `launcher/Data/app.db`, restart and register again.

## Stopping it cleanly

The launcher process is literally `./Launcher`; the components match `solace/build/Release`. Kill both, or the old
launcher keeps port 5050 and its deleted database open while a new one fails to bind.
