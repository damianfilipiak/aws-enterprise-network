terraform {
  backend "s3" {
    bucket       = "awscorponetwork-tfstate-damianfilipiakpl"
    key          = "prod/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = false
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "deploy_ad_connector" {
  description = "MFA Flag"
  type        = bool
  default     = false
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

resource "aws_s3_bucket" "ssm_ansible_bucket" {
  bucket_prefix = "ssm-ansible-payloads-"
  force_destroy = true
}

resource "aws_iam_role_policy" "ssm_s3_transfer" {
  name = "ssm-s3-file-transfer"
  role = aws_iam_role.ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.ssm_ansible_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.ssm_ansible_bucket.arn
      },
      {
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = [
          aws_secretsmanager_secret.ad_password_secret.arn,
          aws_secretsmanager_secret.ad_connector_secret.arn
        ]
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

# AZ A (eu-central-1a)
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

# AZ B (eu-central-1b)
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

# EC2 INSTANCES
resource "aws_instance" "nat_vpn_gateway" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  user_data_replace_on_change = true

  user_data = replace(<<EOF
#!/bin/bash
mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nDNS=169.254.169.253" > /etc/systemd/resolved.conf.d/temp.conf
systemctl restart systemd-resolved

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
iptables -t nat -A POSTROUTING -j MASQUERADE

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf || true

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done
apt-get update -y
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y iptables-persistent
netfilter-persistent save

if ! command -v snap >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y snapd
  systemctl enable --now snapd
fi

if ! systemctl list-unit-files --all | grep -q 'snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  snap install amazon-ssm-agent --classic || true
fi

if systemctl list-unit-files --all | grep -q 'snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
else
  curl -o /tmp/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
  dpkg -i /tmp/amazon-ssm-agent.deb || true
  systemctl enable --now amazon-ssm-agent || true
fi
EOF
  , "\r", "")

  tags       = { Name = "NAT-VPN-Gateway" }
  depends_on = [aws_vpc_dhcp_options_association.ad_dhcp_assoc]
}

resource "aws_eip" "nat_eip" {
  instance = aws_instance.nat_vpn_gateway.id
  domain   = "vpc"
  tags     = { Name = "NAT-VPN-Gateway-EIP" }
}

resource "aws_instance" "ad_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.private_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  private_ip                  = "10.128.30.10"
  user_data_replace_on_change = true

  user_data = replace(<<EOF
#!/bin/bash
set -e

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/10-custom-dns.conf <<'RESOLVEOF'
[Resolve]
DNS=10.128.30.10
DNSSEC=no
Domains=ls.ege.ds
RESOLVEOF
systemctl restart systemd-resolved || true

# Ensure local DNS resolution points to the AD host itself for this VPC domain
cat > /etc/hosts <<'HOSTS'
127.0.0.1 localhost
10.128.30.10 dc.ls.ege.ds dc
HOSTS

for i in {1..36}; do
  if curl -sI https://aws.amazon.com >/dev/null; then break; fi
  sleep 5
done

if ! command -v snap >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y snapd
  systemctl enable --now snapd
fi

if ! systemctl list-unit-files --all | grep -q 'snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  snap install amazon-ssm-agent --classic || true
fi

if systemctl list-unit-files --all | grep -q 'snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
else
  curl -o /tmp/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
  dpkg -i /tmp/amazon-ssm-agent.deb || true
  systemctl enable --now amazon-ssm-agent || true
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf || true

while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done
apt-get update -y
apt-get install -y nfs-common amazon-efs-utils || true

mkdir -p /mnt/shared-data
echo "${aws_efs_file_system.enterprise_storage.id}:/ /mnt/shared-data efs _netdev,tls 0 0" >> /etc/fstab
mount -a -t efs || true
EOF
  , "\r", "")

  tags = { Name = "Samba4-AD-DC" }

  depends_on = [
    aws_route_table_association.private_rta_a,
    aws_route_table_association.private_rta_b,
    aws_efs_mount_target.efs_mount_a,
    aws_vpc_dhcp_options_association.ad_dhcp_assoc,
  ]
}

resource "aws_instance" "office_pc_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_user_subnet_a.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = { Name = "Office-User-Simulator" }

  depends_on = [aws_vpc_dhcp_options_association.ad_dhcp_assoc]
}

resource "aws_instance" "office_pc_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_user_subnet_b.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  tags = { Name = "Office-User-Simulator-B" }

  depends_on = [aws_vpc_dhcp_options_association.ad_dhcp_assoc]
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

resource "aws_route_table_association" "private_user_rta_b" {
  subnet_id      = aws_subnet.private_user_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
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

# OUTPUTS
output "nat_public_ip" {
  value = aws_eip.nat_eip.public_ip
}

output "ad_private_ip" {
  value = aws_instance.ad_server.private_ip
}

output "efs_dns_name" {
  value = aws_efs_file_system.enterprise_storage.dns_name
}

# ANSIBLE INVENTORY
resource "local_file" "ansible_inventory" {
  content  = <<-EOF
    [nat]
    brama ansible_host=${aws_instance.nat_vpn_gateway.id}

    [ad]
    samba_dc ansible_host=${aws_instance.ad_server.id}

    [all:vars]
    ansible_aws_ssm_bucket_name=${aws_s3_bucket.ssm_ansible_bucket.bucket}
    ansible_connection=amazon.aws.aws_ssm
    ansible_aws_ssm_region=eu-central-1
  EOF
  filename = "../ansible/inventory/inventory.ini"
}

# VPC GLOBAL DHCP OPTIONS
resource "aws_vpc_dhcp_options" "ad_dhcp" {
  domain_name         = "ls.ege.ds"
  domain_name_servers = ["10.128.30.10", "AmazonProvidedDNS"]

  tags = { Name = "Enterprise-AD-DHCP" }
}

# Optional: make the private-side DNS behavior explicit for the AD host and AWS Directory Service
resource "aws_route53_resolver_endpoint" "this" {
  count = 0

  name      = "enterprise-dns-resolver"
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.private_sg.id]

  ip_address {
    subnet_id = aws_subnet.private_subnet_a.id
  }

  ip_address {
    subnet_id = aws_subnet.private_subnet_b.id
  }
}

resource "aws_vpc_dhcp_options_association" "ad_dhcp_assoc" {
  vpc_id          = aws_vpc.enterprise_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.ad_dhcp.id
}

# GENERATE PASSWORD
resource "random_password" "ad_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# VAULT AWS SECRETS MANAGER
resource "aws_secretsmanager_secret" "ad_password_secret" {
  name                    = "enterprise/ad/admin-password"
  description             = "Administrator password for Samba Active Directory"
  recovery_window_in_days = 0
}

# PUT PASSWD IN VAULT
resource "aws_secretsmanager_secret_version" "ad_password_version" {
  secret_id     = aws_secretsmanager_secret.ad_password_secret.id
  secret_string = random_password.ad_admin_password.result
}

# OIDC FOR GITHUB
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1b511abead59c6ce207077c0bf0e0043b1382612", "6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM ROLES GITHUB ACTIONS
resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActions-Terraform-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:damianfilipiak/aws-enterprise-network:*"
          }
        }
      }
    ]
  })
}

# TERRAFORM ADMIN PRIVILEGES - CREATE
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}

# PASSWD FOR SERVICE ACC AWS AD CONNECTOR
resource "random_password" "ad_connector_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "ad_connector_secret" {
  name                    = "enterprise/ad/connector-password"
  description             = "Password for AWS AD Connector service account"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ad_connector_version" {
  secret_id     = aws_secretsmanager_secret.ad_connector_secret.id
  secret_string = random_password.ad_connector_password.result
}


# GET PASSWD AWS-SVS
data "aws_secretsmanager_secret_version" "ad_connector_pwd" {
  secret_id  = aws_secretsmanager_secret.ad_connector_secret.id
  depends_on = [aws_secretsmanager_secret_version.ad_connector_version]
}

# AWS AD CONNECTOR
resource "aws_directory_service_directory" "ad_connector" {
  count = var.deploy_ad_connector ? 1 : 0

  name     = "ls.ege.ds"
  password = data.aws_secretsmanager_secret_version.ad_connector_pwd.secret_string
  size     = "Small"
  type     = "ADConnector"

  connect_settings {
    customer_dns_ips  = [aws_instance.ad_server.private_ip]
    customer_username = "aws-svc"
    subnet_ids        = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
    vpc_id            = aws_vpc.enterprise_vpc.id
  }
}


# TEST