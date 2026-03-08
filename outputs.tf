output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID de la subnet pública"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID de la subnet privada"
  value       = aws_subnet.private.id
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway"
  value       = aws_nat_gateway.nat.id
}

output "nat_public_ip" {
  description = "IP pública del NAT — toda la subnet privada sale con esta IP"
  value       = aws_eip.nat.public_ip
}

output "public_security_group_id" {
  description = "ID del SG público"
  value       = aws_security_group.public_sg.id
}

output "private_security_group_id" {
  description = "ID del SG privado"
  value       = aws_security_group.private_sg.id
}

output "resumen" {
  description = "Resumen de la arquitectura desplegada"
  value       = <<-EOT
    ┌─────────────────────────────────────────────┐
    │  VPC:             ${aws_vpc.main.id}
    │  Public  Subnet:  ${aws_subnet.public.cidr_block} (${aws_subnet.public.id})
    │  Private Subnet:  ${aws_subnet.private.cidr_block} (${aws_subnet.private.id})
    │  NAT Gateway IP:  ${aws_eip.nat.public_ip}
    └─────────────────────────────────────────────┘
  EOT
}
