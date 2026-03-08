# ─────────────────────────────────────────
# VPC — el contenedor raíz de toda la red
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  # "aws_vpc" es el tipo de recurso (definido por el provider)
  # "main" es el nombre local en Terraform — se usa para referenciar: aws_vpc.main.id

  cidr_block = var.vpc_cidr # El rango de IPs de toda la red: 10.0.0.0 → 10.0.255.255

  enable_dns_hostnames = true # Permite que las EC2 tengan hostname DNS (ej: ec2-1-2-3-4.compute-1.amazonaws.com)
  enable_dns_support   = true # Habilita el servidor DNS interno de AWS (169.254.169.253)
  # Ambos deben ser true para que Route53 privado funcione luego

  tags = { Name = "${var.environment}-vpc" }
  # "${var.environment}-vpc" es interpolación — genera: "lab-vpc"
  # Los default_tags del provider se fusionan con estos tags automáticamente
}

# ─────────────────────────────────────────
# Internet Gateway — la "puerta" hacia internet
# ─────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  # aws_vpc.main.id → referencia al atributo "id" del recurso VPC que creamos arriba
  # Terraform resuelve esto como una dependencia implícita:
  # el IGW se crea DESPUÉS de la VPC automáticamente

  tags = { Name = "${var.environment}-igw" }
}

# ─────────────────────────────────────────
# Subnet Pública — segmento de red con acceso a internet
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr # 10.0.1.0/24 — subconjunto de la VPC
  availability_zone = var.availability_zone  # En qué datacenter físico vive esta subnet

  map_public_ip_on_launch = true
  # true = cada EC2 que se lance aquí recibe una IP pública automáticamente
  # false (default) = las instancias solo tienen IP privada — no accesibles desde internet

  tags = { Name = "${var.environment}-public-subnet" }
}

# ─────────────────────────────────────────
# Route Table — la "tabla de enrutamiento" que decide hacia dónde va el tráfico
# ─────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                 # "cualquier destino" (tráfico a internet)
    gateway_id = aws_internet_gateway.igw.id # ...mandarlo al Internet Gateway
  }
  # AWS crea automáticamente una ruta local: 10.0.0.0/16 → local
  # Esa ruta permite comunicación entre subnets dentro de la VPC sin definirla aquí

  tags = { Name = "${var.environment}-public-rt" }
}

# Asociación — vincula la Route Table con la Subnet
# Sin esto, la subnet usaría la Route Table por defecto de la VPC (sin ruta a internet)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id      # Qué subnet
  route_table_id = aws_route_table.public.id # Con qué Route Table
}

# ─────────────────────────────────────────
# Security Group — firewall stateful a nivel de recurso
# ─────────────────────────────────────────
resource "aws_security_group" "public_sg" {
  name        = "${var.environment}-public-sg"
  description = "SG para recursos en subnet publica"
  vpc_id      = aws_vpc.main.id
  # Un SG pertenece a una VPC específica — no es global

  # IMPORTANTE: no ponemos reglas inline aquí
  # Las reglas se definen en recursos separados abajo (nuevo patrón desde AWS provider v5)
  # Mezclar ambos enfoques causa conflictos en terraform apply

  tags = { Name = "${var.environment}-public-sg" }
}

# Regla INGRESS (entrada) — puerto 22 SSH
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0" # ⚠️ Abierto a todos — en producción usa tu IP: "X.X.X.X/32"
  from_port         = 22
  to_port           = 22 # from == to porque es un solo puerto
  ip_protocol       = "tcp"
  description       = "SSH - restringir en produccion"
}

# Regla INGRESS — puerto 80 HTTP
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Regla INGRESS — puerto 443 HTTPS
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# Regla EGRESS (salida) — todo el tráfico saliente permitido
resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # "-1" = todos los protocolos (tcp, udp, icmp, etc.)
  # Como los SG son stateful, las RESPUESTAS a conexiones entrantes
  # salen automáticamente sin necesitar esta regla.
  # Esta regla permite que el recurso INICIE conexiones salientes (ej: apt update, curl)
  description = "Permitir todo el trafico de salida"
}
