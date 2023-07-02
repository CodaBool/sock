provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["919759177803"]
}

terraform {
  required_version = ">= 1.4.6, < 2.0.0"
  required_providers {
    aws = {
      version = "< 6.0"
    }
  }
  backend "s3" {
    bucket = "codabool-tf"
    key    = "slap.tfstate"
    region = "us-east-1"
  }
}

# resource "aws_iam_role" "lifecycle" {
#   name_prefix               = "lifecycle"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "dlm.amazonaws.com"
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "lifecycle" {
#   role       = aws_iam_role.lifecycle.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
# }

# TODO: find if these lifecycle policy were killing the instance
# resource "aws_dlm_lifecycle_policy" "instance" {
#   description        = "slap delete instance"
#   execution_role_arn = aws_iam_role.lifecycle.arn
#   policy_details {
#     resource_types = ["INSTANCE"]
#     schedule {
#       name = "every day"
#       create_rule {
#         cron_expression = "cron(0 12 * * ? *)"
#       }
#       retain_rule {
#         count = 1
#       }
#     }
#     target_tags = {
#       Name = "slap"
#     }
#   }
# }

# resource "aws_dlm_lifecycle_policy" "volume" {
#   description        = "slap delete volume"
#   execution_role_arn = aws_iam_role.lifecycle.arn
#   policy_details {
#     resource_types = ["VOLUME"]
#     schedule {
#       name = "every day"
#       create_rule {
#         cron_expression = "cron(0 12 * * ? *)"
#       }
#       retain_rule {
#         count = 1
#       }
#     }
#     target_tags = {
#       Name = "slap"
#     }
#   }
# }

locals {
  name = "sock"
}

module "ec2" {
  source        = "github.com/CodaBool/AWS/modules/ec2"
  name          = local.name # this must match what packer tag named the ami
  instance_type = "t4g.nano"
  price         = data.external.lowest_price.result.price
  ssh_ip        = var.ssh_ip == "" ? data.external.my_ip.result.ip : var.ssh_ip 
  profile_name  = local.name
}

data "external" "my_ip" {
  program = ["curl", "https://ipinfo.io"]
}

module "cloudwatch" {
  source = "github.com/CodaBool/AWS/modules/cloudwatch"
  profile_name  = local.name
}

data "external" "lowest_price" {
  program = ["bash", "price.sh"]
}

output "dns" {
  value = module.ec2.instance.private_dns
}

output "id" {
  value = module.ec2.instance.spot_instance_id
}

variable "ssh_ip" {
  type = string
  default = ""
}