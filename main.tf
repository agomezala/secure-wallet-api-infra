terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.environment}-vpc" }
}

# Internet Gateway (compartido entre todas las AZs)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.environment}-igw" }
}

# Desplegar infraestructura por cada AZ
module "network_az" {
  source   = "./modules/network-az"
  for_each = { for az in var.availability_zones : az.name => az }

  vpc_id              = aws_vpc.main.id
  availability_zone   = each.value.name
  public_subnet_cidr  = each.value.public_subnet_cidr
  private_subnet_cidr = each.value.private_subnet_cidr
  data_subnet_cidr    = each.value.data_subnet_cidr
  igw_id              = aws_internet_gateway.igw.id
  environment         = var.environment
}

# IDENTITY PROVIDER (IAM OIDC para GitHub Actions)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["2b18947a6a9fc7764fd8b5fb18a863b0c6dac24f"]
}

resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsECSRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:agomezala/secure-wallet-api:*"
          }
        }
      }
    ]
  })
}
