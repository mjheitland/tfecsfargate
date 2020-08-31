# app/env to scaffold
region = "eu-central-1"
aws_profile = "default"
app = "my-ecs-fargate-app"
environment = "dev"
container_port = "80"
replicas = "1"
health_check = "/"
saml_role = "AWSServiceRoleForAmazonEKSForFargate"
tags = {
  application   = "my-ecs-fargate-app"
  environment   = "dev"
  team          = ""
  customer      = "bmw"
  contact-email = "michael.heitland@bmw.de"
}

public_vpc_tags = {
  "Name" = "public-vpc-bao"
}
private_vpc_tags = {
  "Name" = "public-vpc-bao"
}

# certificate_arn = "arn:aws:acm:eu-central-1:446113886472:certificate/ebe5dfae-fd48-485a-a6f6-872373bd9e71"
internal = false
