# Copy to terraform.tfvars (git-ignored) and fill in.
ssh_key_name = "my-ec2-keypair" # an existing key pair in aws_region
admin_cidr   = "203.0.113.4/32" # your home IP, for SSH and the admin-UI tunnel
# instance_type     = "t4g.large"     # or t4g.medium to save ~$24/month
# idle_stop_minutes = 20              # 0 keeps it running 24/7
# osm_bbox          = "-122.9,47.2,-122.0,47.9"   # Puget Sound; change to your play area
