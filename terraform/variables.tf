variable "LINODE_TOKEN" {
  type        = string
  description = "The Access Token to authenticate with the Linode Cloud API."
}

locals {
  linode_token = var.LINODE_TOKEN
}