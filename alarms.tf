resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "wallet-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU > 80% durante 2 periodos"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }
  tags = { Name = "wallet-alarm-ecs-cpu" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "wallet-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS Memory > 80% durante 2 periodos"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }
  tags = { Name = "wallet-alarm-ecs-memory" }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "wallet-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx > 10 en 2 periodos"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  tags = { Name = "wallet-alarm-alb-5xx" }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "wallet-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Target group con hosts unhealthy"
  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  tags = { Name = "wallet-alarm-unhealthy-hosts" }
}
