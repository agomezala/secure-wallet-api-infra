resource "aws_ecs_cluster" "main" {
  name = "wallet-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "wallet-cluster" }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/wallet-task"
  retention_in_days = 30
  tags              = { Name = "wallet-task-logs" }
}

resource "aws_ecr_repository" "app" {
  name                 = "wallet-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "wallet-app" }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "wallet-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "wallet-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_xray" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

locals {
  database_url = "postgresql://${aws_db_instance.postgres.username}:${var.rds_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}?sslmode=no-verify"
}

resource "aws_secretsmanager_secret" "database_url" {
  name        = "wallet-database-url"
  description = "Full DATABASE_URL para la wallet API"
  tags        = { Name = "wallet-database-url" }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  secret_string = local.database_url
}

resource "aws_iam_role_policy" "task_secrets" {
  name = "wallet-task-secrets"
  role = aws_iam_role.ecs_task_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = [
          aws_secretsmanager_secret.database_url.arn,
        ]
      },
    ]
  })
}
