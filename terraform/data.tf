# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# OIDC Provider

data "aws_caller_identity" "current" {}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# svc6 sec-s-4 & 5 aspen host and saba host. see how QA and Justin sftp or ftp. setup queries for dnsmasq do rule groups. mostly in cloudfront, prod CD,   