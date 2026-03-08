variable "region" {
  description = "AWS region donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nombre del entorno"
  type        = string
  default     = "lab02"
}

variable "vpc_cidr" {
  description = "CIDR block principal de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subnet pública — aquí vivirá el NAT Gateway"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR de la subnet privada — sin acceso directo desde internet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "AZ donde se crearán ambas subnets"
  type        = string
  default     = "us-east-1a"
}
