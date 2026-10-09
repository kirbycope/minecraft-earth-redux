#!/usr/bin/env bash
# Stop this instance after IDLE_MIN minutes with no game traffic. Installed by user-data, run from cron every 5 min.
#
# Activity signal: any non-listening socket on the API port. The game polls the API every few seconds
# while open, and closed connections linger in TIME-WAIT for about a minute, so "zero sockets" at a
# 5-minute check means nobody has talked to the server for a while. Buildplate UDP ports are not
# consulted: a player in a buildplate still polls the API, so the API port covers that case too.
set -u
API_PORT="${API_PORT:-8080}"
IDLE_MIN="${IDLE_MIN:-20}"
STEP=5
STATE=/var/lib/mce-idle
mkdir -p "$STATE"

[ "$IDLE_MIN" -gt 0 ] || exit 0
# never stop under a running first-boot tile import; it does not resume after a reboot
pgrep -x osm2pgsql >/dev/null && exit 0

active=$(ss -Htan "( sport = :$API_PORT )" | grep -vc LISTEN)
if [ "$active" -gt 0 ]; then
  echo 0 > "$STATE/idle_minutes"
  exit 0
fi

idle=$(( $(cat "$STATE/idle_minutes" 2>/dev/null || echo 0) + STEP ))
echo "$idle" > "$STATE/idle_minutes"
[ "$idle" -ge "$IDLE_MIN" ] || exit 0

echo 0 > "$STATE/idle_minutes"
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
logger -t mce-idle "no game traffic for $IDLE_MIN min, stopping $IID"
aws ec2 stop-instances --region "$REGION" --instance-ids "$IID"
