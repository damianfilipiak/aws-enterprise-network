resource "aws_vpc" "enterprise_vpc" {
  cidr_block           = "10.128.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "Enterprise-VPC" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.enterprise_vpc.id
  tags   = { Name = "Enterprise-IGW" }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.enterprise_vpc.id
  cidr_block              = "10.128.10.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"
  tags                    = { Name = "Public-Subnet-10-A" }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.enterprise_vpc.id
  cidr_block        = "10.128.30.0/24"
  availability_zone = "eu-central-1a"
  tags              = { Name = "Private-Server-Subnet-30-A" }
}

resource "aws_subnet" "private_user_subnet_a" {
  vpc_id            = aws_vpc.enterprise_vpc.id
  cidr_block        = "10.128.40.0/24"
  availability_zone = "eu-central-1a"
  tags              = { Name = "Private-User-Subnet-40-A" }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.enterprise_vpc.id
  cidr_block              = "10.128.11.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1b"
  tags                    = { Name = "Public-Subnet-11-B" }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.enterprise_vpc.id
  cidr_block        = "10.128.31.0/24"
  availability_zone = "eu-central-1b"
  tags              = { Name = "Private-Server-Subnet-31-B" }
}

resource "aws_subnet" "private_user_subnet_b" {
  vpc_id            = aws_vpc.enterprise_vpc.id
  cidr_block        = "10.128.41.0/24"
  availability_zone = "eu-central-1b"
  tags              = { Name = "Private-User-Subnet-41-B" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.enterprise_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public-RT" }
}

resource "aws_route_table_association" "public_rta_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.enterprise_vpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_vpn_gateway.primary_network_interface_id
  }
  tags = { Name = "Private-RT" }
}

resource "aws_route_table_association" "private_rta_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rta_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_user_rta_a" {
  subnet_id      = aws_subnet.private_user_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_user_rta_b" {
  subnet_id      = aws_subnet.private_user_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}
