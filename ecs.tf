# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # Disable for cost optimization
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = 1024 # 1 vCPU for t3.small
  memory                   = 1536 # 1.5 GB total (backend: 512MB, mongo: 1024MB)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name              = "backend"
      image             = "${aws_ecr_repository.backend.repository_url}:latest"
      memory            = 512
      memoryReservation = 256
      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "DB_HOST"
          value = "localhost"
        },
        {
          name  = "DB_PORT"
          value = "27017"
        },
        {
          name  = "DB_NAME"
          value = "CC5_Cinema"
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.backend_storage.bucket
        },
        {
          name  = "CLOUDFRONT_DOMAIN"
          value = aws_cloudfront_distribution.main.domain_name
        }
      ]
      secrets = [
        {
          name      = "CINEMA_JWT_PRIVATE_KEY"
          valueFrom = aws_ssm_parameter.jwt_key.arn
        },
        {
          name      = "MONGO_ROOT_USER"
          valueFrom = aws_ssm_parameter.mongo_user.arn
        },
        {
          name      = "MONGO_ROOT_PASSWORD"
          valueFrom = aws_ssm_parameter.mongo_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      essential = true
    },
    {
      name              = "mongodb"
      image             = "mongo:7.0.7"
      memory            = 1024
      memoryReservation = 512
      command = [
        "mongod",
        "--wiredTigerCacheSizeGB",
        "0.5"
      ]
      portMappings = [
        {
          containerPort = 27017
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "MONGO_INITDB_ROOT_USERNAME"
          valueFrom = aws_ssm_parameter.mongo_user.arn
        },
        {
          name      = "MONGO_INITDB_ROOT_PASSWORD"
          valueFrom = aws_ssm_parameter.mongo_password.arn
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "mongo-data"
          containerPath = "/data/db"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.mongodb.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      essential = true
    }
  ])

  # MongoDB data volume - backed by EFS for persistence across instance replacements
  volume {
    name      = "mongo-data"
    host_path = var.mongo_data_path # This path is mounted to EFS via user_data.sh
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-backend-task"
  })
}

# ECS Service with ALB
resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 3001
  }

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.main,
    aws_lb_listener.backend_http
  ]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-backend-service"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name_prefix}-backend"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-backend-logs"
  })
}

resource "aws_cloudwatch_log_group" "mongodb" {
  name              = "/ecs/${local.name_prefix}-mongodb"
  retention_in_days = 7

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-mongodb-logs"
  })
}
