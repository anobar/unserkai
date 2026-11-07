resource "aws_security_group" "ec2" {
  name   = var.name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "rule" {
  for_each = { for rule in local.rules : rule.name => rule }

  security_group_id = aws_security_group.ec2.id
  description       = each.value.name
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type
  cidr_blocks       = split(";", each.value.cidr_blocks)
}
