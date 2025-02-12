provider "aws" {
  region = "us-east-1"  # Change this to your preferred region
}

# Data source to check if the S3 bucket exists
data "aws_s3_bucket" "existing_lambda_bucket" {
  bucket = "dotnet8-lambda-bucket-unique"
}

# Create an S3 Bucket only if it does not exist
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "dotnet8-lambda-bucket-unique"
  lifecycle {
    prevent_destroy = true
  }
}

# Upload the Lambda ZIP file to S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = "lambda.zip"
  source = "lambda.zip"
  etag   = filemd5("lambda.zip")
}

# Data source to check if the IAM Role already exists
data "aws_iam_role" "existing_lambda_role" {
  name = "lambda-execution-role"
}

# IAM Role for Lambda Execution (Only if not exists)
resource "aws_iam_role" "lambda_role" {
  count = length(data.aws_iam_role.existing_lambda_role) > 0 ? 0 : 1
  name = "lambda-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AWS Lambda Basic Execution Role
resource "aws_iam_policy_attachment" "lambda_basic_execution" {
  name       = "lambda-basic-execution"
  roles      = ["lambda-execution-role"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Data source to check if the IAM Role already exists
data "aws_iam_role" "existing_codebuild_role" {
  name = "codebuild-role"
}

# IAM Role for CodeBuild (Only if not exists)
resource "aws_iam_role" "codebuild_role" {
  count = length(data.aws_iam_role.existing_codebuild_role) > 0 ? 0 : 1
  name = "codebuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AWS Managed Policies for CodeBuild
resource "aws_iam_policy_attachment" "codebuild_policy" {
  name       = "codebuild-policy"
  roles      = ["codebuild-role"]
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# AWS CodeBuild for .NET Lambda Build
resource "aws_codebuild_project" "dotnet_build_project" {
  name          = "dotnet-lambda-build"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:6.0"
    type            = "LINUX_CONTAINER"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}
