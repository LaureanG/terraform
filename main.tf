terraform {
  #    backend "s3" {
  #     bucket = "mybucket"
  #     key    = "path/to/my/key"
  #     region = "us-west-2"
  #   }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "app_server" {
  ami           = "ami-08116b9957a259459"
  instance_type = "t2.micro"
  tags = {
    Name = "AppServerInstance02"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "lgp-terraform-state" //name should be unique

  lifecycle {
    prevent_destroy = true //reject any plan that would distroy infrastructure object related with this resource
    // disable if needed
  }
}

//enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

//enable server side encryption for data saved in this bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

//use public access block to completly block public access to this bucket
//https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

//use DynamoDB key/value store for locking (offers consistent reads and conditional writes)
resource "aws_dynamodb_table" "terraform_state" {
  name         = "terraform-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}