variable "resource-prefix" {}
variable "region" {}

terraform {
  backend "s3" {
    bucket = "pawprint-terraform"
    key    = "main/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      owner      = "GeekFox Lab"
      project    = "Pawprint"
      company    = "GeekFox Lab"
      managed-by = "terraform"
    }
  }
}