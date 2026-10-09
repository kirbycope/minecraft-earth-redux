# AWS deployment (Terraform)

One ARM instance runs the whole stack; a tiny Lambda wakes it. Designed to sleep when nobody is playing.

## How wake-on-launch works

The game's first request on every launch is the **locator**, a JSON answer saying where the API lives. The APK's
locator is pointed at a Lambda Function URL instead of the server. The Lambda starts the EC2 instance if it is
stopped and returns the locator pointing at the server's Elastic IP. An on-instance cron stops the box after
`idle_stop_minutes` with no game traffic. The launcher runs with `--start-on-startup`, so every component comes
back by itself after a wake; nobody has to press Start All.

The one thing this cannot hide: the server takes a moment to boot. Measured on a t4g.large: 34 seconds from the
locator hit to the API answering (the first boot is longer because it builds Solace and imports tiles; after that
the disk is warm). So the first launch after a sleep may show "can't connect"; relaunch half a minute later and it
plays. The game's request timeouts are too short to stall the locator through a boot, so two launches is the floor.

## Deploy

Terraform's AWS provider cannot read an `aws login` session, and nothing should run as the account root anyway, so
first create the scoped deployer user (once, as an admin). `aws/iam/deployer-policy.json` limits it to this project's
EC2/IAM/Lambda resources in us-west-2; the script stores its key in a local profile named `mce`:

```bash
aws/iam/create-deployer.sh
export AWS_PROFILE=mce
```

```bash
cd aws/terraform
cp example.tfvars terraform.tfvars   # set ssh_key_name and admin_cidr
terraform init
terraform apply
```

First boot takes several minutes (it builds Solace from source and imports map tiles in the background; watch
`/var/log/mce-bootstrap.log` and `/var/log/mce-tiles.log`). Then:

1. `terraform output launcher_admin_tunnel`, run it, open http://localhost:5000, register the first account (it
   becomes owner). No mail server: use the confirm link on the confirmation page, or
   `sqlite3 /opt/mce/solace/build/Release/framework-dependent-linux-arm64/launcher/Data/app.db "UPDATE AspNetUsers SET EmailConfirmed=1"`.
2. `terraform output patch_apk_command`, run it against the original APK, install the result on an arm64 Android phone.
3. In the game, Register tab, create the player account (lowercase username), play.

## Cost (us-west-2, on-demand)

| | t4g.medium | t4g.large |
|---|---|---|
| 24/7 | ~$32/mo | ~$56/mo |
| ~3 h/day with idle-stop | ~$10/mo | ~$13/mo |

EBS (~$3) and the Elastic IP (~$4, free the first year) bill even while stopped. Lambda is free-tier. Egress stays
inside the 100 GB free allowance for a handful of players. A 1-year Savings Plan takes ~37% off compute.

## Security notes

- Only the API port and the buildplate UDP range are public. SSH and the admin UI are admin-CIDR / tunnel only.
- The instance can only stop *itself* (tag-scoped); the Lambda can only start *this* instance.
- The Function URL is public by design (the game cannot sign requests). It only lives inside your APK; anyone who
  learns it could start your server and cost you compute, not reach anything on it.
