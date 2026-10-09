# Client patcher

Turns the stock Minecraft Earth 0.33.0 APK into one that talks only to your Solace server.

The APK is not in this repo. Get the original (APKPure has 0.33.0, versionCode 2020121703) and run:

```bash
patcher/patch-apk.sh Minecraft_Earth_0.33.0.apk out/earth.apk 192.168.4.35:8080
```

For the AWS deployment, pass the Lambda locator URL that `terraform output` prints:

```bash
patcher/patch-apk.sh Minecraft_Earth_0.33.0.apk out/earth.apk 3.1.2.3:8080 https://xxxx.lambda-url.us-west-2.on.aws
```

## What it changes

It drives the upstream [Earth-Restored patcher](https://github.com/Earth-Restored/Minecraft_Earth_Patcher) at the commit in
`UPSTREAM_COMMIT`, applying the [Project-Genoa patches](https://github.com/Project-Genoa/patches):

- `change-locator-address`: where the game asks "where is the API" on launch.
- `change-msa-login-address`, `change-xboxlive-address-base/extra`, `change-xboxab-address`, `change-playfab-address`:
  every authentication endpoint, redirected to the server. The server emulates them and runs its own accounts.
- `disable-sunset-time-check`, `disable-license-check`: the June 2021 shutdown date and the Google Play licence.
- `extend-libgenoa`, `allow-http`, `disable-msa-login-signature-validation`: pulled in automatically as prerequisites.

Why this matters: Microsoft decommissioned Minecraft Earth's Xbox Live title. A client that only redirects the locator
still calls the real `auth.xboxlive.com` and gets HTTP 400 at the token exchange. Redirecting all of auth means the
client never contacts Microsoft at all, so the dead title is irrelevant. You sign in with a Solace account instead.

## macOS

Upstream only ships `patchelf` builds for Windows and Linux. `macos-support.patch` makes the patcher use Homebrew's
`patchelf` (`brew install patchelf`) and sets the required `AndroidOSVersion`. The script applies it automatically.

The game's username field accepts lowercase letters, digits, underscore and colon only. Register the in-game
account from the game's own Register tab; it is separate from the launcher admin account.
