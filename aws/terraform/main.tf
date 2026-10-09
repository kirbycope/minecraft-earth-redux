provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { Project = var.project_name }
  }
}

# Ubuntu 24.04 LTS, arm64 (Graviton). Matches the framework-dependent-linux-arm64 Solace build.
data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  service_uri = "http://${aws_eip.server.public_ip}:${var.api_port}"
}
