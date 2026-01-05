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
