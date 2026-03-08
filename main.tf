# ─────────────────────────────────────────────────────────────────
# ARQUITECTURA DE ESTE LAB
#
#   Internet
#      │
#  [IGW]                         ← entrada/salida pública
#      │
#  Public Subnet 10.0.1.0/24
#  ├── [NAT Gateway]             ← permite salida a internet a la subnet privada
#  └── [Elastic IP]              ← IP pública fija asignada al NAT
#      │
#  Private Subnet 10.0.2.0/24
#  └── (recursos internos)       ← sin entrada desde internet, salida via NAT
#
# DIFERENCIA CLAVE vs Lab 01:
#   Public  → Route Table apunta a IGW  → bidireccional (entrada + salida)
#   Private → Route Table apunta a NAT  → solo salida (no hay entrada desde internet)
# ─────────────────────────────────────────────────────────────────


# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.environment}-vpc" }
}


# ─────────────────────────────────────────
# INTERNET GATEWAY
# Permite tráfico bidireccional entre la subnet pública e internet
# ─────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.environment}-igw" }
}


# ─────────────────────────────────────────
# SUBNET PÚBLICA
# Recursos aquí son accesibles desde internet
# El NAT Gateway DEBE vivir en una subnet pública (necesita el IGW)
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = { Name = "${var.environment}-public-subnet" }
}


# ─────────────────────────────────────────
# SUBNET PRIVADA
# Recursos aquí NO son accesibles desde internet directamente
# Pueden salir a internet únicamente a través del NAT Gateway
# ─────────────────────────────────────────
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  # map_public_ip_on_launch = false (es el default — no se asignan IPs públicas)

  tags = { Name = "${var.environment}-private-subnet" }
}


# ─────────────────────────────────────────
# ELASTIC IP para el NAT Gateway
# IP pública fija que representa a toda la subnet privada al salir a internet
# ─────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.environment}-nat-eip" }
}


# ─────────────────────────────────────────
# NAT GATEWAY
# Permite salida a internet desde subnet privada, bloquea entrada
#
# Flujo:  EC2-privada → NAT → IGW → Internet
# ─────────────────────────────────────────
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id # ⚠️ DEBE ser subnet pública

  # Dependencia explícita: el NAT necesita el IGW activo para funcionar
  # Terraform no siempre infiere este orden, lo forzamos aquí
  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "${var.environment}-nat-gw" }
}


# ─────────────────────────────────────────
# ROUTE TABLE PÚBLICA → IGW (entrada + salida)
# ─────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# ─────────────────────────────────────────
# ROUTE TABLE PRIVADA → NAT (solo salida)
# Diferencia clave: nat_gateway_id en vez de gateway_id
# ─────────────────────────────────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id # ← nat_gateway_id, no gateway_id
  }

  tags = { Name = "${var.environment}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


# ─────────────────────────────────────────
# SECURITY GROUP — PÚBLICO
# ─────────────────────────────────────────
resource "aws_security_group" "public_sg" {
  name        = "${var.environment}-public-sg"
  description = "SG para recursos en subnet publica"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.environment}-public-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "public_ssh" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0" # ⚠️ Reemplazar con tu IP /32 en producción
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH - restringir en produccion"
}

resource "aws_vpc_security_group_ingress_rule" "public_http" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "public_all_out" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ─────────────────────────────────────────
# SECURITY GROUP — PRIVADO
# Solo acepta tráfico desde el SG público (referencia entre SGs)
# ─────────────────────────────────────────
resource "aws_security_group" "private_sg" {
  name        = "${var.environment}-private-sg"
  description = "SG para recursos en subnet privada"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.environment}-private-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "private_from_public" {
  security_group_id            = aws_security_group.private_sg.id
  referenced_security_group_id = aws_security_group.public_sg.id # ← referencia por SG, no CIDR
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "SSH solo desde recursos en el SG publico"
}

resource "aws_vpc_security_group_egress_rule" "private_all_out" {
  security_group_id = aws_security_group.private_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  # Permite salida a internet via NAT Gateway
}
