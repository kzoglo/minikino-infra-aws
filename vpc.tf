# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public Subnets (2 for ALB high availability requirement)
resource "aws_subnet" "public" {
  count             = 2 # ALB requires at least 2 subnets in different AZs
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
  })
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = 2 # Match the subnet count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for stable backend endpoint (free tier eligible when attached)
resource "aws_eip" "backend" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-eip"
  })
}

# S3 Gateway Endpoint (FREE - improves performance and security)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  # Associate with public route table for S3 access via private AWS network
  route_table_ids = [aws_route_table.public.id]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}
