# minecraft-earth-redux

Minecraft Earth, playable again on a server you run. Mojang shut the game down in June 2021 and Microsoft later
retired its Xbox Live title, so the stock app cannot sign in anywhere. This repo rebuilds the whole stack:

- a **client APK patched** so every service it talks to, including sign-in, is yours (`patcher/`);
- the **Solace server** that implements the game API and emulates Microsoft/Xbox/PlayFab auth (`server/`);
- **self-hosted map tiles** from OpenStreetMap so the real world shows under your character (`tiles/`);
- **Terraform** for one small AWS box that wakes when you open the game and sleeps when you stop (`aws/`).

Verified end to end on a Galaxy S24 Ultra (Android 16): sign-in, live map with real streets, tappables, crafting,
inventory, store. Buildplates and multiplayer are the part of Solace still marked work-in-progress upstream.

Not in the repo, on purpose: the game APK (get 0.33.0, versionCode 2020121703, from APKPure or your own device),
the signing key the patcher generates, map data and build output.

## Quick paths

**Local (LAN):** build Solace per `server/README.md`, run `tiles/*.sh`, patch the APK with your machine's LAN
address, install, register in-game.

**AWS:** `aws/README.md`. `terraform apply`, register the admin account through the SSH tunnel, run the printed
`patch_apk_command`, install the APK.

Start with `docs/architecture.md` for why it is built this way and `docs/gotchas.md` before you touch anything.

## Credits

Earth-Restored (Solace, patcher), micheal65536 (Vienna, the original full-auth server), Project-Genoa
(the patch set), Project Earth (2021 API and patcher), andiricum2 (resource pack and buildplate archives).
Not affiliated with Mojang or Microsoft; Minecraft and Minecraft Earth are their trademarks.
