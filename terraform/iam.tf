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
          aws_secretsmanager_secret.ad_connector_secret.arn,
          aws_secretsmanager_secret.ad_default_user_secret.arn,
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

variable "skip_github_oidc_provider_creation" {
  description = "Set to true if GitHub OIDC provider already exists in this AWS account"
  type        = bool
  default     = false
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.skip_github_oidc_provider_creation ? 0 : 1
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1b511abead59c6ce207077c0bf0e0043b1382612", "6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_provider_arn = var.skip_github_oidc_provider_creation ? data.aws_iam_openid_connect_provider.github.arn : aws_iam_openid_connect_provider.github[0].arn
}

variable "skip_github_actions_role_creation" {
  description = "Set to true if GitHubActions-Terraform-Role already exists in this AWS account"
  type        = bool
  default     = false
}

resource "aws_iam_role" "github_actions_role" {
  count = var.skip_github_actions_role_creation ? 0 : 1
  name  = "GitHubActions-Terraform-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
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

data "aws_iam_role" "github_actions_role" {
  name = "GitHubActions-Terraform-Role"
}

locals {
  github_actions_role_name = var.skip_github_actions_role_creation ? data.aws_iam_role.github_actions_role.name : aws_iam_role.github_actions_role[0].name
  github_actions_role_arn  = var.skip_github_actions_role_creation ? data.aws_iam_role.github_actions_role.arn : aws_iam_role.github_actions_role[0].arn
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = local.github_actions_role_name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "ecs-task-s3-secrets-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.ssm_ansible_bucket.arn,
          "${aws_s3_bucket.ssm_ansible_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.ad_password_secret.arn,
          aws_secretsmanager_secret.ad_connector_secret.arn,
          aws_secretsmanager_secret.ad_default_user_secret.arn
        ]
      }
    ]
  })
}

