variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Nombre del entorno"
  type        = string
  default     = "wallet"
}

variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de zonas de disponibilidad"
  type = list(object({
    name              = string
    public_subnet_cidr  = string
    private_subnet_cidr = string
    data_subnet_cidr    = string
  }))
  default = [
    {
      name                = "eu-west-1a"
      public_subnet_cidr  = "10.0.1.0/24"
      private_subnet_cidr = "10.0.10.0/24"
      data_subnet_cidr    = "10.0.20.0/24"
    },
    {
      name                = "eu-west-1b"
      public_subnet_cidr  = "10.0.2.0/24"
      private_subnet_cidr = "10.0.11.0/24"
      data_subnet_cidr    = "10.0.21.0/24"
    }
  ]
}

variable "rds_password" {
  description = "Contrasena de la base de datos RDS"
  type        = string
  sensitive   = true
}
