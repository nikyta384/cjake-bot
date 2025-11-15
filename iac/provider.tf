terraform {
  required_version = ">= 1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}


resource "aws_s3_bucket" "artifact_store" {
  bucket = "${var.project_prefix}-codepipeline-artifacts-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "${var.project_prefix}-artifacts"
  }
}


resource "random_id" "suffix" {
  byte_length = 4
}