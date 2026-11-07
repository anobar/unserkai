output "aws_instance" {
  value = aws_instance.this
}

output "dns_name" {
  value = local.dns_name
}

output "aws_iam_role" {
  value = aws_iam_role.ec2-role
}

output "public_fqdn" {
  value = aws_route53_record.ec2public.0.fqdn
}

output "subnet_id" {
  value = local.instance_subnet_id
  description = "subnet_id used for the ec2 instance"
}

output "availability_zone" {
  value = data.aws_subnet.selected.availability_zone
  description = "availability zone used for the ec2 instance"
}
