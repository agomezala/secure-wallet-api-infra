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
