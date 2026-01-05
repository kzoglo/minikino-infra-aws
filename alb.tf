# Application Load Balancer
resource "aws_lb" "backend" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# Target Group for Backend API
resource "aws_lb_target_group" "backend" {
  name        = "${local.name_prefix}-backend-tg"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # For awsvpc network mode

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health" # Dedicated health check endpoint
    matcher             = "200"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-backend-tg"
  })
}

# ALB Listener (HTTP only - CloudFront handles HTTPS)
resource "aws_lb_listener" "backend_http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
