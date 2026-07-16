terraform {
  backend "s3" {
    bucket = "awscorponetwork-tfstate-damianfilipiakpl"
    key    = "prod/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_key_pair" "admin_key" {
  key_name   = "enterprise-admin-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# IAM for AWS SSM
resource "aws_iam_role" "ssm_role" {
  name = "Enterprise-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "Enterprise-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}

# DATA (AMI)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Multi-AZ VPC & SUBNETS
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

# STREFA A (eu-central-1a)
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
  tags              = { Name = "Private-Subnet-30-A" }
}

# STREFA B (eu-central-1b) - backup
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
  tags              = { Name = "Private-Subnet-31-B" }
}

# FIREWALL / SECURITY GROUPS
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Private-Servers-SG" }
}

resource "aws_security_group" "efs_sg" {
  name        = "EFS-Storage-SG"
  vpc_id      = aws_vpc.enterprise_vpc.id

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

# AMAZON EFS
resource "aws_efs_file_system" "enterprise_storage" {
  creation_token   = "enterprise-shared-data"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true 

  tags = { Name = "Enterprise-Shared-Storage" }
}

resource "aws_efs_mount_target" "efs_mount_a" {
  file_system_id  = aws_efs_file_system.enterprise_storage.id
  subnet_id       = aws_subnet.private_subnet_a.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "efs_mount_b" {
  file_system_id  = aws_efs_file_system.enterprise_storage.id
  subnet_id       = aws_subnet.private_subnet_b.id
  security_groups = [aws_security_group.efs_sg.id]
}

# EC2 (NAT & AD)
resource "aws_instance" "nat_vpn_gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  source_dest_check      = false
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = aws_key_pair.admin_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              sysctl -p
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
              echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
              apt-get install -y iptables-persistent
              iptables -t nat -A POSTROUTING -j MASQUERADE
              netfilter-persistent save
              EOF
  tags = { Name = "NAT-VPN-Gateway" }
}

resource "aws_eip" "nat_eip" {
  instance = aws_instance.nat_vpn_gateway.id
  domain   = "vpc"
  tags     = { Name = "NAT-VPN-Gateway-EIP" }
}

resource "aws_instance" "ad_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  key_name               = aws_key_pair.admin_key.key_name
  private_ip             = "10.128.30.10"

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y nfs-common amazon-efs-utils

              mkdir -p /mnt/shared-data
              echo "${aws_efs_file_system.enterprise_storage.id}:/ /mnt/shared-data efs _netdev,tls 0 0" >> /etc/fstab
              mount -a -t efs || mount -a
              EOF

  tags = { Name = "Samba4-AD-DC" }

  depends_on = [
    aws_route_table_association.private_rta_a,
    aws_route_table_association.private_rta_b,
    aws_efs_mount_target.efs_mount_a,
  ]
}

# ROUTING
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

# OUTPUTS & ANSIBLE CONFIG
output "nat_public_ip" {
  value = aws_eip.nat_eip.public_ip
}
output "ad_private_ip" {
  value = aws_instance.ad_server.private_ip
}
output "efs_dns_name" {
  value = aws_efs_file_system.enterprise_storage.dns_name
}

# ANSIBLE INVENTORY (SSH over SSM)
resource "local_file" "ansible_inventory" {
  content = <<-EOF
    [nat]
    brama ansible_host=${aws_instance.nat_vpn_gateway.id} ansible_user=ubuntu

    [ad]
    samba_dc ansible_host=${aws_instance.ad_server.id} ansible_user=ubuntu

    [all:vars]
    ansible_ssh_common_args='-o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p" -o StrictHostKeyChecking=no'
  EOF
  filename = "../ansible/inventory/inventory.ini"
}

# DHCP for AD
resource "aws_vpc_dhcp_options" "ad_dhcp" {
  domain_name         = "ls.ege.ds"
  domain_name_servers = ["10.128.30.10"] # IP Twojego serwera Samba AD DC

  tags = {
    Name = "Enterprise-AD-DHCP"
  }
}

resource "aws_vpc_dhcp_options_association" "ad_dhcp_assoc" {
  vpc_id          = aws_vpc.enterprise_vpc.id # Zaktualizowana nazwa Twojego VPC!
  dhcp_options_id = aws_vpc_dhcp_options.ad_dhcp.id
}

# Test User1
resource "aws_instance" "office_pc_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = {
    Name = "Office-User-Simulator"
  }
}
