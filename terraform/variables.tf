variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "eu-central-1"
}

variable "ad_primary_private_ip" {
  description = "Primary AD DC private IP"
  type        = string
  default     = "10.10.30.10"
}

variable "ad_replica_private_ip" {
  description = "Replica AD DC private IP"
  type        = string
  default     = "10.10.31.10"
}

variable "enable_client_vpn" {
  description = "Enable AWS Client VPN endpoint and routing"
  type        = bool
  default     = false
}

variable "client_vpn_client_cidr" {
  description = "Client CIDR block assigned to VPN clients (must not overlap VPC CIDRs)"
  type        = string
  default     = "172.31.252.0/22"
}

variable "client_vpn_server_certificate_arn" {
  description = "ACM ARN of server certificate for AWS Client VPN"
  type        = string
  default     = ""
}

variable "client_vpn_root_certificate_chain_arn" {
  description = "ACM ARN of root CA certificate chain for client certificate authentication"
  type        = string
  default     = ""
}

variable "internal_form_desired_count" {
  description = "Desired number of internal form ECS tasks"
  type        = number
  default     = 2
}
