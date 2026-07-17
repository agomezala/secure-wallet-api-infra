output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "availability_zones" {
  description = "Recursos por zona de disponibilidad"
  value = {
    for az_name, az_module in module.network_az : az_name => {
      public_subnet_id  = az_module.public_subnet_id
      private_subnet_id = az_module.private_subnet_id
      data_subnet_id    = az_module.data_subnet_id
      nat_gateway_id    = az_module.nat_gateway_id
    }
  }
}

output "private_subnet_ids" {
  description = "Lista de IDs de subnets privadas (para ECS tasks)"
  value       = [for az in module.network_az : az.private_subnet_id]
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "ARN del rol de IAM que debe asumir GitHub Actions para autenticarse"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "URL del registro ECR donde se subirán las imágenes Docker"
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Dirección DNS pública del Load Balancer para acceder a la API"
}

output "alb_target_group_arn" {
  value       = aws_lb_target_group.app.arn
  description = "ARN del Target Group del ALB (para asociar ECS service)"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Nombre del cluster ECS (para desplegar el service)"
}

output "ecs_cluster_arn" {
  value       = aws_ecs_cluster.main.arn
  description = "ARN del cluster ECS"
}

output "ecs_security_group_id" {
  value       = aws_security_group.ecs.id
  description = "ID del security group de ECS (para asignar a las ENIs de las tasks)"
}

output "ecs_execution_role_arn" {
  value       = aws_iam_role.ecs_execution_role.arn
  description = "ARN del rol de ejecución de ECS (para task definition)"
}

output "ecs_task_role_arn" {
  value       = aws_iam_role.ecs_task_role.arn
  description = "ARN del rol de tarea de ECS (para task definition)"
}

output "rds_endpoint" {
  value       = aws_db_instance.postgres.address
  description = "Hostname del endpoint de RDS"
}

output "rds_port" {
  value       = aws_db_instance.postgres.port
  description = "Puerto de conexión de RDS"
}

output "rds_database_name" {
  value       = aws_db_instance.postgres.db_name
  description = "Nombre de la base de datos en RDS"
}

output "rds_username" {
  value       = aws_db_instance.postgres.username
  description = "Usuario maestro de RDS"
}

output "database_url_secret_arn" {
  value       = aws_secretsmanager_secret.database_url.arn
  description = "ARN del secret en Secrets Manager con la DATABASE_URL completa"
}
