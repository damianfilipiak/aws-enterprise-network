resource "aws_s3_bucket" "ssm_ansible_bucket" {
  bucket_prefix = "ssm-ansible-payloads-"
  force_destroy = true
}

resource "aws_vpc_dhcp_options" "ad_dhcp" {
  domain_name         = "corp.local"
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = { Name = "Enterprise-AD-DHCP" }
}

resource "aws_vpc_dhcp_options_association" "ad_dhcp_assoc" {
  vpc_id          = aws_vpc.enterprise_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.ad_dhcp.id
}

resource "random_password" "ad_admin_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "ad_connector_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "ad_default_user_password" {
  length           = 18
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "ad_password_secret" {
  name                    = "enterprise/ad/admin-password"
  description             = "Administrator password for Samba Active Directory"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "ad_connector_secret" {
  name                    = "enterprise/ad/connector-password"
  description             = "Password for AWS AD Connector service account"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret" "ad_default_user_secret" {
  name                    = "enterprise/ad/default-user-password"
  description             = "Default bootstrap password for AD demo users"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "ad_password_version" {
  secret_id     = aws_secretsmanager_secret.ad_password_secret.id
  secret_string = random_password.ad_admin_password.result
}

resource "aws_secretsmanager_secret_version" "ad_connector_password_version" {
  secret_id     = aws_secretsmanager_secret.ad_connector_secret.id
  secret_string = random_password.ad_connector_password.result
}

resource "aws_secretsmanager_secret_version" "ad_default_user_password_version" {
  secret_id     = aws_secretsmanager_secret.ad_default_user_secret.id
  secret_string = random_password.ad_default_user_password.result
}

resource "local_file" "ansible_inventory" {
  content = <<-EOF

    [ad_primary]
    samba_dc_primary ansible_host=${aws_instance.ad_server.id}

    [ad_replica]
    samba_dc_replica ansible_host=${aws_instance.ad_server_replica.id}

    [ad]
    samba_dc_primary
    samba_dc_replica

    [all:vars]
    ansible_aws_ssm_bucket_name=${aws_s3_bucket.ssm_ansible_bucket.bucket}
    ansible_connection=amazon.aws.aws_ssm
    ansible_aws_ssm_region=${var.aws_region}
  EOF

  filename = "../ansible/inventory/inventory.ini"
}
