# AWS Budgets for cost monitoring and alerts

resource "aws_budgets_budget" "monthly_cost" {
  name         = "${local.name_prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_tax          = true
    include_subscription = true
    use_blended          = false
  }

  # Budget alerts/notifications at 50%, 80%, and 100% thresholds
  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 50
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    subscriber_email_addresses = [var.alert_email]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-budget"
  })
}
