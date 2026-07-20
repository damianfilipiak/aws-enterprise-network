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
set -e

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/10-custom-dns.conf <<'RESOLVEOF'
[Resolve]
DNS=169.254.169.253
DNSSEC=no
RESOLVEOF
systemctl restart systemd-resolved || true

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
