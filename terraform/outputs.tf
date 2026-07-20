output "nat_public_ip" {
  value = aws_eip.nat_eip.public_ip
}

output "ad_private_ip" {
  value = aws_instance.ad_server.private_ip
}

output "efs_dns_name" {
  value = aws_efs_file_system.enterprise_storage.dns_name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}
