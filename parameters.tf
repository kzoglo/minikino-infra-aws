# Parameter Store Parameters for Environment Variables

# JWT Private Key
resource "aws_ssm_parameter" "jwt_key" {
  name        = "/${local.name_prefix}/jwt-private-key"
  description = "JWT private key for authentication"
  type        = "SecureString"
  value       = var.jwt_private_key

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-jwt-key"
  })
}

# MongoDB Root User
resource "aws_ssm_parameter" "mongo_user" {
  name        = "/${local.name_prefix}/mongo-root-user"
  description = "MongoDB root username"
  type        = "String"
  value       = var.mongo_root_user

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-mongo-user"
  })
}

# MongoDB Root Password
resource "aws_ssm_parameter" "mongo_password" {
  name        = "/${local.name_prefix}/mongo-root-password"
  description = "MongoDB root password"
  type        = "SecureString"
  value       = var.mongo_root_password

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-mongo-password"
  })
}

# Non-sensitive deployment parameters
resource "aws_ssm_parameter" "aws_region" {
  name        = "/${local.name_prefix}/aws-region"
  description = "AWS region for deployments"
  type        = "String"
  value       = var.aws_region

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-aws-region"
  })
}

resource "aws_ssm_parameter" "ecr_repository_url" {
  name        = "/${local.name_prefix}/ecr-repository-url"
  description = "ECR repository URL for backend"
  type        = "String"
  value       = aws_ecr_repository.backend.repository_url

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecr-repo-url"
  })
}

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name        = "/${local.name_prefix}/ecs-cluster-name"
  description = "ECS cluster name"
  type        = "String"
  value       = aws_ecs_cluster.main.name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-cluster-name"
  })
}

resource "aws_ssm_parameter" "ecs_service_name" {
  name        = "/${local.name_prefix}/ecs-service-name"
  description = "ECS service name"
  type        = "String"
  value       = aws_ecs_service.backend.name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-service-name"
  })
}

resource "aws_ssm_parameter" "s3_frontend_bucket" {
  name        = "/${local.name_prefix}/s3-frontend-bucket"
  description = "S3 bucket name for frontend"
  type        = "String"
  value       = aws_s3_bucket.frontend.bucket

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-s3-frontend-bucket"
  })
}

resource "aws_ssm_parameter" "cloudfront_url" {
  name        = "/${local.name_prefix}/cloudfront-url"
  description = "CloudFront URL for frontend and API"
  type        = "String"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudfront-url"
  })
}

resource "aws_ssm_parameter" "cloudfront_domain" {
  name        = "/${local.name_prefix}/cloudfront-domain"
  description = "CloudFront domain name"
  type        = "String"
  value       = aws_cloudfront_distribution.main.domain_name

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudfront-domain"
  })
}

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name        = "/${local.name_prefix}/cloudfront-distribution-id"
  description = "CloudFront distribution ID"
  type        = "String"
  value       = aws_cloudfront_distribution.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cloudfront-distribution-id"
  })
}
