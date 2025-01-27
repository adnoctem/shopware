terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    profile              = "delta4x4-terraform"
    bucket               = "terraform.delta4x4"
    key                  = "tfstate.json"
    region               = "eu-north-1"
    workspace_key_prefix = "delta4x4/shopware" # instead of 'env:'
  }

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "2.33.0" # recent versions fail
    }
  }
}

provider "linode" {
  token = var.LINODE_TOKEN != "" ? var.LINODE_TOKEN : local.linode_token
}