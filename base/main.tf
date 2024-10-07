terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16"
    }
  }
  backend "s3" {
    bucket         = "wk-ups007-tf-state-bucket"
    key            = "tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "wk-ups007-dynamodb-tf-state-table"
  }
}

provider "aws" {
  region = var.aws_region
  shared_credentials_files = ["/home/wk/.aws/credentials"]
  profile = "pa"
}

variable "STATE_BUCKET" {
  type = string
}


resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd", "6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags = {
    Name = "${var.pre}ip"
    Owner = var.owner
  }
}


resource "aws_iam_role" "github_role" {
  name = "${var.pre}github-role"
  assume_role_policy = data.aws_iam_policy_document.github_policy_doc.json
  tags = {
    Name = "${var.pre}github-role"
    Owner = var.owner
  }
}

data "aws_iam_policy_document" "github_policy_doc" {
  statement {
    sid     = "AllowAssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:shcodenick/djcrud:*"]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  statement {
    sid     = "AllowAssumeRoleWithWebIdentity2"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:shcodenick/ups007-aws-infra:*"]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
  statement {
    sid     = "AllowAssumeRoleWithWebIdentity3"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:shcodenick/s3writer:*"]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}


resource "aws_iam_role_policy" "github_role_policy" {
    role     = aws_iam_role.github_role.id
    policy   = data.aws_iam_policy_document.access_state_bucket.json
}

data "aws_iam_policy_document" "access_state_bucket" {
  statement {
    sid       = "AllowAccessToStateBucket"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.STATE_BUCKET}/*", "arn:aws:s3:::${var.STATE_BUCKET}"]
  }

  # yeah
  statement {
    sid       = "AllowAccessToS3"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowAccessEC2"
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowAccessELB"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowAccessCloudWatch"
    effect    = "Allow"
    actions   = ["cloudwatch:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowAccessRDS"
    effect    = "Allow"
    actions   = ["rds:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowAccessECS"
    effect    = "Allow"
    actions   = ["ecs:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowSTS"
    effect    = "Allow"
    actions   = ["sts:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowLogs"
    effect    = "Allow"
    actions   = ["logs:*"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowIAM"
    effect    = "Allow"
    actions   = ["iam:CreateRole", "iam:TagRole", "iam:AttachRolePolicy", "iam:PassRole"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowSGetRolePolicy"
    effect    = "Allow"
    actions   = ["iam:GetRolePolicy", "iam:GetOpenIDConnectProvider", "iam:GetRole", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowDynamoDBActions"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowAccessToECR"
    effect    = "Allow"
    actions   = [
      "ecr:*"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "AllowServiceDiscovery"
    effect    = "Allow"
    actions   = ["servicediscovery:*"]
    resources = ["*"]
  }
  statement {
    sid       = "AllowRoute53"
    effect    = "Allow"
    actions   = ["route53:*"]
    resources = ["*"]
  }
}
