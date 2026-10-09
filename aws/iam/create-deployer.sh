#!/usr/bin/env bash
# One-time, run as an admin: create the IAM user Terraform deploys with, limited to this project's
# resources in us-west-2 (deployer-policy.json), and store its access key in a local AWS profile.
# Terraform's AWS provider cannot read `aws login` sessions, so a plain access key is needed anyway.
#
#   aws/iam/create-deployer.sh            # creates user + profile "mce"
#   AWS_PROFILE=mce terraform plan ...
set -euo pipefail
USER_NAME="${1:-minecraft-earth-redux-deployer}"
PROFILE="${2:-mce}"
here="$(cd "$(dirname "$0")" && pwd)"
aws iam get-user --user-name "$USER_NAME" >/dev/null 2>&1 || aws iam create-user --user-name "$USER_NAME" --tags Key=Project,Value=minecraft-earth-redux >/dev/null
# inline user policies cap at 2 KB, so this is a customer-managed policy (6 KB); re-runs push a new version
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::$ACCOUNT:policy/$USER_NAME"
if aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  for v in $(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?!IsDefaultVersion].VersionId' --output text); do
    aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$v"; done
  aws iam create-policy-version --policy-arn "$POLICY_ARN" --policy-document "file://$here/deployer-policy.json" --set-as-default >/dev/null
else
  aws iam create-policy --policy-name "$USER_NAME" --policy-document "file://$here/deployer-policy.json" >/dev/null
fi
aws iam attach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN"
# rotate: at most one key, so a re-run replaces it
for k in $(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
  aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$k"
done
key_json="$(aws iam create-access-key --user-name "$USER_NAME" --query 'AccessKey' --output json)"
aws configure set aws_access_key_id     "$(echo "$key_json" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["AccessKeyId"])')"     --profile "$PROFILE"
aws configure set aws_secret_access_key "$(echo "$key_json" | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["SecretAccessKey"])')" --profile "$PROFILE"
aws configure set region us-west-2 --profile "$PROFILE"
echo "profile '$PROFILE' written to ~/.aws/credentials for user $USER_NAME"
