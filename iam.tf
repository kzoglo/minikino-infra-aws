# ECS Execution Role - ECS service when starting containers (pulling images)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-execution-role"
  })
}

# ECS Task Role - Your running backend application
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-task-role"
  })
}

# ECS Agent Role - The ECS agent software on your EC2 instance
resource "aws_iam_role" "ecs_agent" {
  name = "${local.name_prefix}-ecs-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-agent-role"
  })
}

# ECS Agent Instance Profile
resource "aws_iam_instance_profile" "ecs_agent" {
  name = "${local.name_prefix}-ecs-agent-profile"
  role = aws_iam_role.ecs_agent.name
}

# ECS Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Agent Role Policy
resource "aws_iam_role_policy_attachment" "ecs_agent_role_policy" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# ECS Agent Role Policy for Elastic IP Association
resource "aws_iam_role_policy" "ecs_agent_eip_policy" {
  name = "${local.name_prefix}-ecs-agent-eip-policy"
  role = aws_iam_role.ecs_agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Agent Role Policy for ECR Access (required for pulling images)
resource "aws_iam_role_policy" "ecs_agent_ecr_policy" {
  name = "${local.name_prefix}-ecs-agent-ecr-policy"
  role = aws_iam_role.ecs_agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Agent Role Policy for EFS Access (required for IAM-based EFS mounting)
resource "aws_iam_role_policy" "ecs_agent_efs_policy" {
  name = "${local.name_prefix}-ecs-agent-efs-policy"
  role = aws_iam_role.ecs_agent.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess",
          "elasticfilesystem:DescribeFileSystems"
        ]
        Resource = aws_efs_file_system.mongo_data.arn
      }
    ]
  })
}

# S3 Access Policy for Task Role
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${local.name_prefix}-ecs-task-s3-policy"
  role = aws_iam_role.ecs_task_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.backend_storage.arn,
          "${aws_s3_bucket.backend_storage.arn}/*"
        ]
      }
    ]
  })
}

# Parameter Store Access Policy for Execution Role
resource "aws_iam_role_policy" "ecs_execution_ssm_policy" {
  name = "${local.name_prefix}-ecs-execution-ssm-policy"
  role = aws_iam_role.ecs_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          aws_ssm_parameter.jwt_key.arn,
          aws_ssm_parameter.mongo_user.arn,
          aws_ssm_parameter.mongo_password.arn
        ]
      }
    ]
  })
}
