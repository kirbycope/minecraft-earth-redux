# --- network: one Elastic IP so the address baked into the APK never changes ---
resource "aws_eip" "server" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-ip" }
}

resource "aws_security_group" "server" {
  name        = "${var.project_name}-sg"
  description = "Minecraft Earth Solace server"

  ingress {
    description = "Solace API (game traffic)"
    from_port   = var.api_port
    to_port     = var.api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Buildplate Minecraft servers (Bedrock UDP), one port per concurrent buildplate"
    from_port   = 19132
    to_port     = 19141
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH from admin only. The launcher UI (port 5000) is reached through an SSH tunnel, never exposed."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  dynamic "ingress" {
    for_each = var.expose_admin_ui ? [1] : []
    content {
      description = "Launcher admin UI, admin CIDR only (expose_admin_ui)"
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      cidr_blocks = [var.admin_cidr]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- IAM: the instance may stop itself when idle, nothing more ---
data "aws_iam_policy_document" "instance_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "instance_self_stop" {
  statement {
    actions   = ["ec2:StopInstances"]
    resources = ["arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Project"
      values   = [var.project_name]
    }
  }
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.project_name}-instance"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json
}

resource "aws_iam_role_policy" "instance_self_stop" {
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance_self_stop.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_name}-instance"
  role = aws_iam_role.instance.name
}

# --- the server ---
resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu_arm64.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  # Bootstraps Solace, PostGIS tiles, the auto-start service and the idle-stop cron on first boot.
  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    public_ip         = aws_eip.server.public_ip
    api_port          = var.api_port
    solace_commit     = var.solace_commit
    resourcepack_url  = var.resourcepack_url
    tiles_enabled     = var.tiles_enabled
    osm_extract_url   = var.osm_extract_url
    osm_bbox          = var.osm_bbox
    idle_stop_minutes = var.idle_stop_minutes
    idle_stop_script  = file("${path.module}/idle-stop.sh")
    server_props_seed = file("${path.module}/../../server/server.properties.seed")
  })
  # Never let a config edit replace a running server. Replacement deletes the root volume and with it
  # every player account, inventory and buildplate. Both of these only matter at first boot anyway:
  # user_data (the bootstrap, which embeds idle-stop.sh) and the "most recent" AMI lookup. A pending
  # edit to idle-stop.sh once rode along on an unrelated apply and rebuilt the instance from scratch.
  # To rebuild on purpose: back up first (aws/teardown.sh does), then `terraform taint aws_instance.server`.
  user_data_replace_on_change = false
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = { Name = "${var.project_name}-server" }
}

resource "aws_eip_association" "server" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server.id
}
