# How it works

## What the client needs

Minecraft Earth is a thin client over a service. On launch it fetches a locator (where is the API), signs in
through Microsoft account -> Xbox Live token -> PlayFab session -> game API sign-in, downloads a resource pack
from the CDN, then drives everything (map, tappables, inventory, crafting, buildplates) through the API.

Mojang shut all of that down on 30 June 2021, and Microsoft later retired the game's Xbox Live title
(id 2037747551). That retirement is the hard wall: a client that still talks to the real Xbox Live gets
HTTP 400 at the token exchange no matter what server sits behind it.

## The two generations of community servers

**Project Earth (2021)** re-implemented the API and patched only the locator. It worked while Microsoft's title
was still alive. Its patches and the `ciilu/mcearth-server` fork still build and serve the whole game API, but
sign-in dies at Xbox Live now.

**Vienna / Solace (2024 on)** goes further: the `Project-Genoa/patches` set redirects *every* auth endpoint
(`live.com`, `xboxlive.com`, `xboxab.com`, `playfabapi.com`) to the server, and the server emulates them with
its own account system. The client never contacts Microsoft. This is what makes the game playable in 2026 and
what this repo deploys. Solace is the maintained fork of Vienna.

## Pieces in this repo

| Dir | Role |
|---|---|
| `patcher/` | Builds the client APK: all-auth redirect + sunset and licence patches, via the upstream patcher at a pinned commit, with a macOS compatibility patch. |
| `server/` | Solace at a pinned commit, plus the first-run seeds (EULA, event-bus properties, launcher config). |
| `tiles/` | PostGIS + osm2pgsql import so the map shows real streets without a third-party tile service. |
| `aws/` | Terraform: one Graviton instance, Elastic IP, Lambda locator/waker, idle auto-stop. |

## Data flow on AWS

```
phone ──locator──▶ Lambda URL ──start if stopped──▶ EC2
  │                   └── returns {serviceUri: http://<EIP>:8080}
  └──auth + API + CDN + tiles──▶ EC2:8080 (Solace API, emulated MS/Xbox/PlayFab)
  └──buildplate play (Bedrock UDP)──▶ EC2:19132+ (Fabric MC server per buildplate)
EC2 ──cron: no API traffic for N min──▶ stops itself
```
