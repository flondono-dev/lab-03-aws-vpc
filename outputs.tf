output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID de la subnet pública"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr" {
  description = "CIDR de la subnet pública"
  value       = aws_subnet.public.cidr_block
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "public_route_table_id" {
  description = "ID de la Route Table pública"
  value       = aws_route_table.public.id
}

output "public_security_group_id" {
  description = "ID del Security Group público"
  value       = aws_security_group.public_sg.id
}

output "aws_console_vpc_url" {
  description = "URL directa a la VPC en la consola AWS"
  value       = "https://${var.region}.console.aws.amazon.com/vpc/home?region=${var.region}#VpcDetails:VpcId=${aws_vpc.main.id}"
}
