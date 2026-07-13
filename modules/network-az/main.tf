# Subnet Pública (ALB y NAT Gateway)
resource "aws_subnet" "public" {
  vpc_id            = var.vpc_id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zone
  tags              = { Name = "${var.environment}-public-${var.availability_zone}" }
}

# Subnet Privada (ECS Fargate)
resource "aws_subnet" "private" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone
  tags              = { Name = "${var.environment}-private-${var.availability_zone}" }
}

# Subnet de Datos (RDS)
resource "aws_subnet" "data" {
  vpc_id            = var.vpc_id
  cidr_block        = var.data_subnet_cidr
  availability_zone = var.availability_zone
  tags              = { Name = "${var.environment}-data-${var.availability_zone}" }
}

# Elastic IP para NAT Gateway
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [var.igw_id]
  tags       = { Name = "${var.environment}-nat-eip-${var.availability_zone}" }
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "${var.environment}-nat-${var.availability_zone}" }
  depends_on    = [var.igw_id]
}

# Route Table Pública
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = { Name = "${var.environment}-public-rt-${var.availability_zone}" }
}

# Route Table Privada
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "${var.environment}-private-rt-${var.availability_zone}" }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
