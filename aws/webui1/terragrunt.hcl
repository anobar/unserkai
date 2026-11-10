include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"
}
dependency "route53" {
  config_path = "../route53"
}

inputs = {
  vpc_id              = dependency.vpc.outputs.vpc.vpc.id
  private_subnet_1_id = dependency.vpc.outputs.vpc.private_subnet[0].id
  private_subnet_ids  = dependency.vpc.outputs.vpc.private_subnet[*].id
  route53_public_hostedzone_id = dependency.route53.outputs.domain.hosted_zone_id
}
