# Outputs
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "cloudfront_url" {
  description = "CloudFront URL (serves frontend at / and images at /images/*)"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "cloudfront_domain" {
  description = "CloudFront domain name (use this in backend config)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "alb_url" {
  description = "ALB HTTPS URL for backend API"
  value       = "https://${aws_lb.backend.dns_name}"
}

output "backend_url" {
  description = "Backend API endpoint (via ALB HTTPS)"
  value       = "https://${aws_lb.backend.dns_name}"
}

output "elastic_ip" {
  description = "Elastic IP address for backend"
  value       = aws_eip.backend.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "s3_frontend_bucket" {
  description = "S3 bucket name for frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "s3_backend_storage_bucket" {
  description = "S3 bucket name for backend storage (images)"
  value       = aws_s3_bucket.backend_storage.bucket
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.backend.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "parameter_store_paths" {
  description = "Parameter Store paths for environment variables"
  value = {
    jwt_key        = aws_ssm_parameter.jwt_key.name
    mongo_user     = aws_ssm_parameter.mongo_user.name
    mongo_password = aws_ssm_parameter.mongo_password.name
  }
}

output "efs_file_system_id" {
  description = "EFS file system ID for MongoDB data"
  value       = aws_efs_file_system.mongo_data.id
}
