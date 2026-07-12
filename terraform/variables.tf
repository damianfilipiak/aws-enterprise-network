variable "admin_ip" {
  description = "Public admin IP"
  type        = string
}

variable "public_key_path" {
  description = "public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}