resource "aws_security_group" "client_vpn_sg" {
  count       = var.enable_client_vpn ? 1 : 0
  name        = "Client-VPN-SG"
  description = "Security group attached to AWS Client VPN endpoint"
  vpc_id      = aws_vpc.enterprise_vpc.id

  ingress {
    description = "Client VPN TLS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Client-VPN-SG" }
}

resource "aws_ec2_client_vpn_endpoint" "users_vpn" {
  count                  = var.enable_client_vpn ? 1 : 0
  description            = "Enterprise users VPN endpoint"
  server_certificate_arn = var.client_vpn_server_certificate_arn
  client_cidr_block      = var.client_vpn_client_cidr
  split_tunnel           = true
  dns_servers            = [aws_instance.ad_server.private_ip]
  vpc_id                 = aws_vpc.enterprise_vpc.id
  security_group_ids     = [aws_security_group.client_vpn_sg[0].id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.client_vpn_root_certificate_chain_arn
  }

  connection_log_options {
    enabled = false
  }

  tags = { Name = "Enterprise-Client-VPN" }
}

resource "aws_ec2_client_vpn_network_association" "users_vpn_assoc_a" {
  count                  = var.enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.users_vpn[0].id
  subnet_id              = aws_subnet.private_user_subnet_a.id
}

resource "aws_ec2_client_vpn_network_association" "users_vpn_assoc_b" {
  count                  = var.enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.users_vpn[0].id
  subnet_id              = aws_subnet.private_user_subnet_b.id
}

resource "aws_ec2_client_vpn_authorization_rule" "users_subnets_auth" {
  count                  = var.enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.users_vpn[0].id
  target_network_cidr    = "10.10.40.0/23"
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_authorization_rule" "ad_subnets_auth" {
  count                  = var.enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.users_vpn[0].id
  target_network_cidr    = "10.10.30.0/23"
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_route" "users_subnets_route" {
  count                  = var.enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.users_vpn[0].id
  destination_cidr_block = "10.10.40.0/23"
  target_vpc_subnet_id   = aws_subnet.private_user_subnet_a.id
  depends_on = [
    aws_ec2_client_vpn_network_association.users_vpn_assoc_a,
    aws_ec2_client_vpn_network_association.users_vpn_assoc_b
  ]
}

resource "aws_ec2_client_vpn_route" "ad_subnets_route" {
  count                  = var.enable_client_vpn ? 1 : 0
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.users_vpn[0].id
  destination_cidr_block = "10.10.30.0/23"
  target_vpc_subnet_id   = aws_subnet.private_user_subnet_a.id
  depends_on = [
    aws_ec2_client_vpn_network_association.users_vpn_assoc_a,
    aws_ec2_client_vpn_network_association.users_vpn_assoc_b
  ]
}
