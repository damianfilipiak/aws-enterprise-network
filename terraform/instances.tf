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



resource "aws_instance" "ad_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private_subnet_a.id
  vpc_security_group_ids      = [aws_security_group.private_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  private_ip                  = var.ad_primary_private_ip
  user_data_replace_on_change = true

  user_data = replace(<<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf || true

# Force host-level resolver to AWS VPC DNS only.
if systemctl list-unit-files --all | grep -q 'systemd-resolved.service'; then
  systemctl stop --no-block systemd-resolved || true
  systemctl disable --now systemd-resolved || true
  systemctl mask systemd-resolved || true
fi
rm -f /etc/resolv.conf || true
cat > /etc/resolv.conf <<'RESOLV'
nameserver 169.254.169.253
options timeout:1 attempts:2
RESOLV

for i in {1..36}; do
  if curl -sI https://aws.amazon.com >/dev/null; then break; fi
  sleep 5
done

apt-get update -y
apt-get install -y snapd nfs-common

if ! systemctl list-unit-files --all | grep -q 'snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  snap install amazon-ssm-agent --classic || true
fi
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true

mkdir -p /mnt/shared-data
echo "${aws_efs_file_system.enterprise_storage.dns_name}:/ /mnt/shared-data nfs4 nfsvers=4.1,_netdev,noresvport 0 0" >> /etc/fstab
mount -a -t nfs4 || true
EOF
  , "\r", "")

  tags = { Name = "Samba4-AD-DC" }

  depends_on = [
    aws_nat_gateway.nat_gw,
    aws_route_table_association.private_rta_a,
    aws_route_table_association.private_rta_b,
    aws_efs_mount_target.efs_mount_a,
    aws_vpc_dhcp_options_association.ad_dhcp_assoc
  ]
}

resource "aws_instance" "ad_server_replica" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.private_subnet_b.id
  vpc_security_group_ids      = [aws_security_group.private_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  private_ip                  = var.ad_replica_private_ip
  user_data_replace_on_change = true

  user_data = replace(<<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf || true

# Force host-level resolver to AWS VPC DNS only.
if systemctl list-unit-files --all | grep -q 'systemd-resolved.service'; then
  systemctl stop --no-block systemd-resolved || true
  systemctl disable --now systemd-resolved || true
  systemctl mask systemd-resolved || true
fi
rm -f /etc/resolv.conf || true
cat > /etc/resolv.conf <<'RESOLV'
nameserver 169.254.169.253
options timeout:1 attempts:2
RESOLV

for i in {1..36}; do
  if curl -sI https://aws.amazon.com >/dev/null; then break; fi
  sleep 5
done

apt-get update -y
apt-get install -y snapd nfs-common

if ! systemctl list-unit-files --all | grep -q 'snap.amazon-ssm-agent.amazon-ssm-agent.service'; then
  snap install amazon-ssm-agent --classic || true
fi
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true

mkdir -p /mnt/shared-data
echo "${aws_efs_file_system.enterprise_storage.dns_name}:/ /mnt/shared-data nfs4 nfsvers=4.1,_netdev,noresvport 0 0" >> /etc/fstab
mount -a -t nfs4 || true
EOF
  , "\r", "")

  tags = { Name = "Samba4-AD-DC-Replica" }

  depends_on = [
    aws_nat_gateway.nat_gw,
    aws_route_table_association.private_rta_a,
    aws_route_table_association.private_rta_b,
    aws_efs_mount_target.efs_mount_b,
    aws_vpc_dhcp_options_association.ad_dhcp_assoc
  ]
}
