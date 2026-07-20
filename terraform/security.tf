resource "aws_security_group" "public_sg" {
  name        = "Public-Gateway-SG"
  description = "WireGuard tunnel, VPC communication (No SSH)"
  vpc_id      = aws_vpc.enterprise_vpc.id

  ingress {
    description = "WireGuard tunnel"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "VPC (2 zones, NAT return traffic)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.128.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Public-Gateway-SG" }
}

resource "aws_security_group" "private_sg" {
  name        = "Private-Servers-SG"
  description = "Full VPC communication for all private server"
  vpc_id      = aws_vpc.enterprise_vpc.id

  ingress {
    description = "VPC communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "DNS TCP from private VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "DNS UDP from private VPC"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "LDAP from private VPC"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "Kerberos TCP from private VPC"
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "Kerberos UDP from private VPC"
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "Kerberos password change TCP from private VPC"
    from_port   = 464
    to_port     = 464
    protocol    = "tcp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  ingress {
    description = "Kerberos password change UDP from private VPC"
    from_port   = 464
    to_port     = 464
    protocol    = "udp"
    cidr_blocks = ["10.128.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Private-Servers-SG" }
}

resource "aws_security_group" "efs_sg" {
  name   = "EFS-Storage-SG"
  vpc_id = aws_vpc.enterprise_vpc.id

  ingress {
    description     = "NFS for private servers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.private_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "EFS-Storage-SG" }
}
