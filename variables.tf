variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "minikino"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "your-domain.com"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Sensitive parameters
variable "jwt_private_key" {
  description = "JWT private key for authentication"
  type        = string
  sensitive   = true
}

variable "mongo_root_user" {
  description = "MongoDB root username"
  type        = string
  default     = "root"
}

variable "mongo_root_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
}

variable "mongo_data_path" {
  description = "Mount path for MongoDB data directory"
  type        = string
  default     = "/mnt/mongo-data"
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 50
}

variable "alert_email" {
  description = "Email address for budget alerts"
  type        = string
}
