provider "aws" {
  version                 = "~> 2.25"
  region                  = "us-east-1"
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "ivoy-production"
}
provider "random" {
  version = "~> 2.2"
}
######################################
# Data sources to get VPC and subnets
######################################
data "aws_vpc" "default" {
  default = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${data.aws_vpc.default.id}"
}
module "subnets" {
  source              = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=master"
  namespace           = "evidences subnets"
  stage               = "${var.environment}"
  name                = "evidence-subnets"
  vpc_id              = "${data.aws_vpc.default.id}"
  igw_id              = "${aws_internet_gateway.igw.id}"
  cidr_block          = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b"]
}

#############
# RDS Aurora
#############
module "aurora" {
  source                              = "terraform-aws-modules/rds-aurora/aws"
  version                             = "~> 2.0"
  name                                = "evidences-database"
  engine                              = "aurora"  
  subnets                             = module.subnets.public_subnet_ids
  vpc_id                              = "${data.aws_vpc.default.id}"
  replica_count                       = 1
  instance_type                       = "db.t3.medium"
  apply_immediately                   = true
  skip_final_snapshot                 = true
  publicly_accessible                 = true
  tags = {
    Service     = "${var.serviceName}"
    Environment = "${var.environment}"
    Terraform   = "true"
  }
}

module "evidence_service_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/mysql"
  version = "~> 3.0"

  name        = "evidences-service"
  description = "Security group for evidences-service with custom ports open within VPC"
  vpc_id = "${data.aws_vpc.default.id}"

  ingress_cidr_blocks = ["10.10.0.0/16"]
}



