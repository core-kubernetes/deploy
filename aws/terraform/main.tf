terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_eip" "this" {
  for_each = var.instance_ids

  instance = each.value
  domain   = "vpc"

  tags = {
    Name = "${each.key}-eip"
  }
}
