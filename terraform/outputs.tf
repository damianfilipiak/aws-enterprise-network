output "nat_public_ip" {
  value = aws_eip.nat_gw_eip.public_ip
}

output "ad_private_ip" {
  value = aws_instance.ad_server.private_ip
}

output "ad_replica_private_ip" {
  value = aws_instance.ad_server_replica.private_ip
}

output "efs_dns_name" {
  value = aws_efs_file_system.enterprise_storage.dns_name
}

output "github_actions_role_arn" {
  value = local.github_actions_role_arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.office_sim.name
}

output "ecs_service_name" {
  value = aws_ecs_service.office_sim_service.name
}

output "client_vpn_endpoint_id" {
  value = var.enable_client_vpn ? aws_ec2_client_vpn_endpoint.users_vpn[0].id : null
}

output "internal_form_alb_dns_name" {
  value = aws_lb.internal_form_alb.dns_name
}
