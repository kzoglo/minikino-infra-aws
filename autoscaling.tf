# Launch Template for ECS Spot Instances
resource "aws_launch_template" "ecs_spot" {
  name_prefix   = "${local.name_prefix}-ecs-spot-"
  image_id      = data.aws_ami.ecs.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ecs_host.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name       = aws_ecs_cluster.main.name
    efs_file_system_id = aws_efs_file_system.mongo_data.id
    mongo_data_path    = var.mongo_data_path
    eip_allocation_id  = aws_eip.backend.id
    aws_region         = var.aws_region
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_agent.name
  }

  monitoring {
    enabled = false # Disable for cost optimization
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "${local.name_prefix}-ecs-spot-instance"
    })
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecs-spot-lt"
  })
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "${local.name_prefix}-ecs-asg"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs_spot.id
        version            = "$Latest"
      }
    }
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ecs-spot-instance"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Auto Scaling Group Capacity Provider
resource "aws_ecs_capacity_provider" "spot" {
  name = "${local.name_prefix}-spot"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-spot-cp"
  })
}

# Attach Capacity Provider to Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.spot.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.spot.name
  }
}
