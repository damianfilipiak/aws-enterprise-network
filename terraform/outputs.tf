output "nat_public_ip" {
  value = aws_eip.nat_gw_eip.public_ip
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

output "ecs_cluster_name" {
  value = aws_ecs_cluster.office_sim.name
}

output "ecs_service_name" {
  value = aws_ecs_service.office_sim_service.name
}
