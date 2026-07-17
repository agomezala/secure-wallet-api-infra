resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/ecs/wallet-flow-logs"
  retention_in_days = 30
  tags              = { Name = "wallet-flow-logs" }
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "flow_logs_permissions" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "wallet-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
  tags               = { Name = "wallet-flow-logs-role" }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "wallet-flow-logs-policy"
  role   = aws_iam_role.flow_logs.name
  policy = data.aws_iam_policy_document.flow_logs_permissions.json
}

resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  tags            = { Name = "wallet-vpc-flow-log" }
}
