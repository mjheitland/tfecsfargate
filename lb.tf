#------------------
#--- Data Providers
#------------------

data "aws_vpc" "public_vpc" {
  tags = var.public_vpc_tags
}

data "aws_subnet_ids" "public_subnets" {
  vpc_id = data.aws_vpc.public_vpc.id
}

data "aws_vpc" "private_vpc" {
  tags = var.private_vpc_tags
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = data.aws_vpc.private_vpc.id
}


#----------
#--- Locals
#----------

locals {
  public_vpc_id       = data.aws_vpc.public_vpc.id
  public_subnet_ids   = data.aws_subnet_ids.public_subnets.ids
  private_vpc_id      = data.aws_vpc.private_vpc.id
  private_subnet_ids  = data.aws_subnet_ids.private_subnets.ids
}


#-------------
#--- Variables
#-------------

variable "public_vpc_tags" {
  description = "complete list of tags associated with the public VPC where we are putting our load balancer - variable 'internal' decides whether we use the public or private vpc)"
  type        = map
}

variable "private_vpc_tags" {
  description = "complete list of tags associated with the private VPC where we are putting our load balancer - variable 'internal' decides whether we use the public or private vpc)"
  type        = map
}

# note that this creates the alb, target group, and access logs
# the listeners are defined in lb-http.tf and lb-https.tf
# delete either of these if your app doesn't need them
# but you need at least one

# The amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused
variable "deregistration_delay" {
  default = "30"
}

# The path to the health check for the load balancer to know if the container(s) are ready
variable "health_check" {
}

# How often to check the liveliness of the container
variable "health_check_interval" {
  default = "30"
}

# How long to wait for the response on the health check path
variable "health_check_timeout" {
  default = "10"
}

# What HTTP response code to listen for
variable "health_check_matcher" {
  default = "200"
}

variable "lb_access_logs_expiration_days" {
  default = "3"
}

resource "aws_alb" "main" {
  name = "${var.app}-${var.environment}"

  # launch lbs in public or private subnets based on "internal" variable
  internal = var.internal
  subnets  = var.internal == true ? local.private_subnet_ids : local.public_subnet_ids
  security_groups = [aws_security_group.nsg_lb.id]
  tags            = var.tags

  # enable access logs in order to get support from aws
  access_logs {
    enabled = true
    bucket  = aws_s3_bucket.lb_access_logs.bucket
  }
}

resource "aws_alb_target_group" "main" {
  name                 = "${var.app}-${var.environment}"
  port                 = var.lb_port
  protocol             = var.lb_protocol
  vpc_id               = var.internal == true ? local.private_vpc_id : local.public_vpc_id
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.health_check
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  tags = var.tags
}

data "aws_elb_service_account" "main" {
}

# bucket for storing ALB access logs
resource "aws_s3_bucket" "lb_access_logs" {
  bucket        = "${var.app}-${var.environment}-lb-access-logs-${data.aws_caller_identity.current.account_id}"
  acl           = "private"
  tags          = var.tags
  force_destroy = true

  lifecycle_rule {
    id                                     = "cleanup"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 1
    prefix                                 = ""

    expiration {
      days = var.lb_access_logs_expiration_days
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# give load balancing service access to the bucket
resource "aws_s3_bucket_policy" "lb_access_logs" {
  bucket = aws_s3_bucket.lb_access_logs.id

  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.lb_access_logs.arn}",
        "${aws_s3_bucket.lb_access_logs.arn}/*"
      ],
      "Principal": {
        "AWS": [ "${data.aws_elb_service_account.main.arn}" ]
      }
    }
  ]
}
POLICY
}

# The load balancer DNS name
output "lb_dns" {
  value = aws_alb.main.dns_name
}
