terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.55"
    }
  }

  required_version = ">= 1.7.0"

  backend "s3" {
    bucket = "aseel-k8s-state"
    key    = "tfstate.json"
    region = "eu-north-1"
    # optional: dynamodb_table = "<table-name>"
  }
}

provider "aws" {
  region  = var.region
  #profile = "default"  # change in case you want to work with another AWS account profile
}


module "polybot_service_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "cluster-vpc"
  cidr = "10.0.0.0/16"

  azs             = var.az
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Env         = var.env
  }
}


module "k8s-cluster" {
  source             = "./modules/k8s-cluster"
  region             = var.region
  ami_id             = var.ami_id
  instance_type      = var.control_plane_instance_type
  key_name           = var.key_name
  vpc_id             = module.polybot_service_vpc.vpc_id
  subnets_id          = module.polybot_service_vpc.public_subnets
  availability_zone   =  var.az
  vpc_cidr = module.polybot_service_vpc.vpc_cidr_block
  route53_zone_id  = var.route53_zone_id

}

