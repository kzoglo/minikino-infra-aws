# EFS File System - One Zone for MongoDB data persistence
resource "aws_efs_file_system" "mongo_data" {
  creation_token = "${local.name_prefix}-mongo-data"
  encrypted      = true

  # One Zone storage class for cost optimization
  availability_zone_name = data.aws_availability_zones.available.names[0]

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS" # Move to cheaper storage after 30 days
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-mongo-data-efs"
  })
}

# EFS Mount Target - connects EFS to VPC subnet
resource "aws_efs_mount_target" "mongo_data" {
  file_system_id  = aws_efs_file_system.mongo_data.id
  subnet_id       = aws_subnet.public[0].id
  security_groups = [aws_security_group.efs.id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${local.name_prefix}-efs-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EFS mount targets"

  # Allow NFS traffic from ECS host instances
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_host.id]
    description     = "NFS access from ECS host instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-sg"
  })
}
