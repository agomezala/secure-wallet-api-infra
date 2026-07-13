variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "availability_zone" {
  description = "Zona de disponibilidad (ej: eu-west-1a)"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR para subnet pública"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR para subnet privada"
  type        = string
}

variable "data_subnet_cidr" {
  description = "CIDR para subnet de datos"
  type        = string
}

variable "igw_id" {
  description = "ID del Internet Gateway"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno (ej: wallet)"
  type        = string
  default     = "wallet"
}
