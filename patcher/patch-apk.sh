#!/usr/bin/env bash
# Patch the Minecraft Earth 0.33.0 APK (versionCode 2020121703) to use a Solace server.
#
#   patcher/patch-apk.sh <original.apk> <output.apk> <api-host:port> [locator-url]
#
#   api-host:port  where the Solace API server is reachable, e.g. 192.168.4.35:8080 or 3.1.2.3:8080.
#                  Every auth endpoint (Microsoft login, Xbox Live, Xbox account, PlayFab) is redirected
#                  here, so the client never contacts Microsoft. This is what defeats the dead Earth
#                  Xbox title: the old locator-only patch left the client calling the real Xbox Live.
#   locator-url    optional. Defaults to http://<api-host:port>. For the AWS wake-on-launch design pass the
#                  Lambda Function URL (https://xxxx.lambda-url.<region>.on.aws), which starts the server
#                  and answers the locator; the 128-byte string slots from extend-libgenoa fit it.
#
# Builds the Earth-Restored patcher CLI from the pinned upstream commit on first run. On macOS it also
# applies macos-support.patch (upstream only ships patchelf for Windows/Linux) and needs `brew install patchelf`.
# Needs .NET 10 (`dotnet`), Java 17, git. Android 15+ page-size patching is on (AndroidOSVersion=16).
set -euo pipefail
# absolute paths: the CLI runs from its own build directory (it resolves Patches/ relative to cwd)
src="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
mkdir -p "$(dirname "$2")"; out="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
api="$3"; locator="${4:-http://$api}"
here="$(cd "$(dirname "$0")" && pwd)"
commit="$(cat "$here/UPSTREAM_COMMIT")"
work="$here/build/patcher"

if [ ! -d "$work" ]; then
  git clone https://github.com/Earth-Restored/Minecraft_Earth_Patcher.git "$work"
  git -C "$work" checkout -q "$commit"
  if [ "$(uname)" = "Darwin" ]; then git -C "$work" apply "$here/macos-support.patch"; fi
  (cd "$work" && dotnet build src/Cli/MCEPatcher.Cli.csproj -c Release)
fi

# split locator into protocol + host as the patcher's variables expect
case "$locator" in
  https://*) lproto="https://"; lhost="${locator#https://}" ;;
  http://*)  lproto="http://";  lhost="${locator#http://}" ;;
  *)         lproto="http://";  lhost="$locator" ;;
esac
lhost="${lhost%/}"

# The CLI resolves Patches/ relative to its working directory.
cd "$work/src/Cli/bin/Release/net10.0"
dotnet ./MCEPatcher.Cli.dll "$src" "$out" non-interactive \
  -p disable-sunset-time-check disable-license-check change-locator-address \
     change-msa-login-address change-playfab-address change-xboxab-address \
     change-xboxlive-address-base change-xboxlive-address-extra \
  -v "locatorprotocol=$lproto" "locatorhostname=$lhost" \
     "liveprotocol=http://$api/"     "livehostname=live.com" \
     "playfabprotocol=http://$api/"  "playfabhostname=playfabapi.com" \
     "xboxabprotocol=http://$api/"   "xboxabhostname=xboxab.com" \
     "xboxliveprotocol=http://$api/" "xboxlivehostname=xboxlive.com" \
  < /dev/null
echo "patched: $out"
