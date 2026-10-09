# Things that cost hours

- **Locator-only patching is a dead end.** It leaves the client calling the real Xbox Live, which returns 400 for
  the retired title. Redirect all of auth (see `patcher/`).
- **The Xbox title id is baked into `libgenoa.so`**, not `res/raw/xboxservices.config`. Editing the config does
  nothing. (And swapping it to a live title would mean forging an identity to Microsoft; not done here.)
- **Earth has no offline mode.** The engine strings (`Play Offline`) are Bedrock leftovers; all content is served.
- **Game username vs admin account.** The in-game account is created in the game's Register tab and lives in the
  API's `earth.db`. The launcher admin account is ASP.NET Identity in `launcher/Data/app.db`. Renaming the admin
  through the Edit dialog silently reset its password via a prefilled field; recover by deleting `app.db`.
- **Stopping the launcher:** the process is `./Launcher`; components match `solace/build/Release`. A half-killed
  launcher keeps the port and its deleted database open.
- **macOS specifics:** AirPlay holds port 5000 (Kestrel endpoint in `appsettings.json` overrides
  `ASPNETCORE_URLS`, change it there); Homebrew `postgis` is built for postgresql@17/18, not 16; the upstream
  patcher has no macOS `patchelf` (`patcher/macos-support.patch`); the one-time Fabric setup run needs the
  event-bus properties seeded.
- **Disk.** A whole-state `osm2pgsql --slim` import wrote the Mac to 0 bytes free, which blocks every process
  that writes anything, including the tooling driving the machine. Import a metro bbox, non-slim, and keep
  headroom. Recovery needed a real terminal: kill osm2pgsql/postgres, remove the cluster, purge snapshots.
- **Android 15+** needs 16 KB page-size patching of the native libs (the patcher does it with `patchelf`).
- **A rebuilt server rejects every existing client session.** Solace signs its emulated Xbox/PlayFab tokens with
  secrets it generates on first run and keeps in `data/earth.db`. A fresh instance has new secrets, so a phone
  that signed in before shows a login refusal and the server logs `JWT verification failed: IDX10511`. The
  phone's cached token has to go: uninstall the app (or clear its data), then sign in or register again.
  Restoring `earth.db` from a backup brings the old secrets back and keeps sessions valid.
