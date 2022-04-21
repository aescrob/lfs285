terraform {
  backend "remote" {
    organization = "aroweb"
    workspaces {
      name = "Example-Workspace"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["691173103445"] # amazon
}

resource "aws_instance" "control_plane" {
  count           = var.no_cp
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  security_groups = ["launch-wizard-1", ]
  key_name        = var.key_name

  tags = {
    Name = "${var.instance_name}-control-plane-${count.index}"
  }
}

resource "aws_instance" "worker_node" {
  count           = var.no_wn
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  security_groups = ["launch-wizard-1", ]
  key_name        = var.key_name

  tags = {
    Name = "${var.instance_name}-worker-node-${count.index}"
  }
}

