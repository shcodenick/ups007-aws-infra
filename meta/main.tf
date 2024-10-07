terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16"
    }
  }
  # local backend
}

provider "aws" {
  region = var.aws_region
  shared_credentials_files = ["/home/machine/.aws/credentials"]
  profile = "pa"
}

resource "aws_dynamodb_table" "tf_state_table" {
  name           = "${var.pre}dynamodb-tf-state-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.pre}dynamodb-table"
    Owner = var.owner
  }
}

# BUCKET FOR TF STATE

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = "${var.pre}tf-state-bucket"

  tags = {
    Name = "${var.pre}tf-state-bucket"
    Owner = var.owner
  }
}

resource "aws_s3_bucket_ownership_controls" "s3_ownership" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [aws_s3_bucket_ownership_controls.s3_ownership]

  bucket = aws_s3_bucket.tf_state_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}
