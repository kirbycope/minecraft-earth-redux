#!/usr/bin/env bash
# Sunset the AWS deployment. Backs up the server's data first, then removes everything this repo created.
#
#   aws/teardown.sh --dry-run        # show what would be deleted; changes nothing
#   aws/teardown.sh                  # back up, then destroy (asks once)
#   aws/teardown.sh --no-backup      # skip the backup
#   aws/teardown.sh --remove-deployer  # also delete the IAM deployer user and policy (needs an admin session)
#
# What goes, in order:
#   1. backup of the instance's data to aws/backups/<timestamp>/  (player accounts, inventories,
#      buildplates, admin accounts, launcher config) -- the root volume dies with the instance
#   2. terraform destroy: instance, Elastic IP, security group, IAM roles, Lambda + URL
#   3. the Lambda's CloudWatch log group (Lambda creates it outside Terraform)
#   4. the EC2 key pair imported by hand before the first apply
#   5. (--remove-deployer) the IAM user/policy from aws/iam, run with the admin profile,
#      because the deployer cannot delete itself
# Local terraform state stays on disk; delete aws/terraform/terraform.tfstate* yourself once you are sure.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; tf="$here/terraform"
DRY=false; BACKUP=true; REMOVE_DEPLOYER=false
for a in "$@"; do case "$a" in
  --dry-run) DRY=true ;; --no-backup) BACKUP=false ;; --remove-deployer) REMOVE_DEPLOYER=true ;;
  *) echo "unknown option $a"; exit 2 ;; esac; done

export AWS_PROFILE="${AWS_PROFILE:-mce}"
region="$(cd "$tf" && terraform output -raw aws_region 2>/dev/null || echo us-west-2)"
ip="$(cd "$tf" && terraform output -raw public_ip 2>/dev/null || true)"
iid="$(cd "$tf" && terraform state show aws_instance.server 2>/dev/null | awk '/^ *id *=/{gsub(/"/,"",$3);print $3}')"
fn="$(cd "$tf" && terraform state show aws_lambda_function.waker 2>/dev/null | awk '/^ *function_name *=/{gsub(/"/,"",$3);print $3}')"
key="$(cd "$tf" && terraform state show aws_instance.server 2>/dev/null | awk '/^ *key_name *=/{gsub(/"/,"",$3);print $3}')"
echo "deployment: instance=${iid:-?} ip=${ip:-?} lambda=${fn:-?} keypair=${key:-?} region=$region profile=$AWS_PROFILE"

run() { if $DRY; then echo "  [dry-run] $*"; else "$@"; fi; }

# 1. backup -------------------------------------------------------------------------------------
if $BACKUP && [ -n "$ip" ]; then
  dest="$here/backups/$(date +%Y%m%d-%H%M%S)"
  B=/opt/mce/solace/build/Release/framework-dependent-linux-arm64
  echo "== 1. backup server data to $dest"
  if $DRY; then
    echo "  [dry-run] start instance if stopped, then scp from $ip: $B/data (earth.db, live.db, object_store), $B/launcher/Data/app.db, $B/launcher/config.json"
  else
    state="$(aws ec2 describe-instances --region "$region" --instance-ids "$iid" --query 'Reservations[0].Instances[0].State.Name' --output text)"
    if [ "$state" = "stopped" ]; then echo "  waking the instance for the backup"; aws ec2 start-instances --region "$region" --instance-ids "$iid" >/dev/null; aws ec2 wait instance-running --region "$region" --instance-ids "$iid"; fi
    for i in $(seq 1 30); do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o BatchMode=yes "ubuntu@$ip" true 2>/dev/null && break; sleep 10; done
    mkdir -p "$dest"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@$ip" "sudo systemctl stop solace; sudo tar -C $B -czf - data launcher/Data/app.db launcher/config.json" > "$dest/solace-data.tar.gz"
    ls -la "$dest/solace-data.tar.gz"
  fi
fi

# 2. terraform destroy ---------------------------------------------------------------------------
echo "== 2. terraform destroy"
if $DRY; then (cd "$tf" && terraform plan -destroy -input=false -no-color | grep -E '^\s*# .* will be destroyed|Plan:' | sed 's/^\s*/  /')
else
  read -r -p "Destroy the AWS deployment (type yes): " ok; [ "$ok" = yes ] || { echo "aborted"; exit 1; }
  (cd "$tf" && terraform destroy -auto-approve -input=false)
fi

# 3. log group, 4. key pair ---------------------------------------------------------------------
echo "== 3. Lambda log group"; [ -n "$fn" ] && run aws logs delete-log-group --region "$region" --log-group-name "/aws/lambda/$fn" || true
echo "== 4. key pair";        [ -n "$key" ] && run aws ec2 delete-key-pair --region "$region" --key-name "$key" || true

# 5. deployer (admin session) --------------------------------------------------------------------
if $REMOVE_DEPLOYER; then
  echo "== 5. IAM deployer user and policy (admin profile 'default')"
  user=minecraft-earth-redux-deployer
  acct="$(AWS_PROFILE=default aws sts get-caller-identity --query Account --output text)"
  parn="arn:aws:iam::$acct:policy/$user"
  if $DRY; then echo "  [dry-run] detach $parn, delete its versions and the policy, delete access keys, delete user $user, remove profile $AWS_PROFILE"
  else
    export AWS_PROFILE=default
    aws iam detach-user-policy --user-name "$user" --policy-arn "$parn" || true
    for v in $(aws iam list-policy-versions --policy-arn "$parn" --query 'Versions[?!IsDefaultVersion].VersionId' --output text); do aws iam delete-policy-version --policy-arn "$parn" --version-id "$v"; done
    aws iam delete-policy --policy-arn "$parn" || true
    for k in $(aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do aws iam delete-access-key --user-name "$user" --access-key-id "$k"; done
    aws iam delete-user --user-name "$user"
  fi
fi
echo "done. Remaining: local terraform state in $tf and the profile in ~/.aws/credentials."
