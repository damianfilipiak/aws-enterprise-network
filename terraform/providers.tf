terraform {
  backend "s3" {
    bucket       = "awscorponetwork-tfstate-damianfilipiakpl"
    key          = "prod/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = false
  }
}

provider "aws" {
  region = var.aws_region
}
