locals {
  # allow to pass AMI ID via var.ec2_ami_id but skip passing valid var.ami_name_pattern
  # i.e. if var.ami_name_pattern is empty string - data.aws_ami.ami won't be created
  ec2_ami_id     = length(var.ami_name_pattern) > 0 ? coalesce(var.ec2_ami_id, data.aws_ami.ami[0].id) : var.ec2_ami_id
  rules          = coalesce(var.firewall_rules, csvdecode(file("${path.module}/firewall_rules.csv")))
  dns_name       = coalesce(var.dns_name, replace(var.name, "_", "-"))
  enable_ssh_key = length(var.ssh_public_key) > 0 ? true : false

  # generate random index for subnet id's
  subnet_ids_random_index = random_id.index.dec % length(var.subnet_ids)
  # retrieve random subnet_id if the list contains values
  random_subnet_id = length(var.subnet_ids) > 0 ? var.subnet_ids[local.subnet_ids_random_index] : null
  # final subnet id
  instance_subnet_id = coalesce(var.subnet_id,local.random_subnet_id)
}

# generate random id for random subnet choosing
resource "random_id" "index" {
  byte_length = 2
}

data "aws_subnet" "selected" {
  id = local.instance_subnet_id
}
