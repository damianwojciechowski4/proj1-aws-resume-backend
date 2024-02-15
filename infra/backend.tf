terraform {
   required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"


  backend "s3" {
    bucket = "github-oidc-terraform-aws-tfstates-05022024"
    key = "state/terraform.tfstate"
    region = "eu-central-1"
    encrypt = true
    dynamodb_table = "myIaC-terraform-lockid"
    
  }
}