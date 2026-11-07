resource "aws_route53_record" "ec2public" {
  count   = length(var.route53_public_hostedzone_id) > 0 ? 1 : 0
  zone_id = var.route53_public_hostedzone_id
  name    = local.dns_name
  type    = "A"
  ttl     = "30"
  records = [aws_instance.this.private_ip]
}

resource "aws_route53_record" "ec2private" {
  count   = length(var.route53_private_hostedzone_id) > 0 ? 1 : 0
  zone_id = var.route53_private_hostedzone_id
  name    = local.dns_name
  type    = "A"
  ttl     = "30"
  records = [aws_instance.this.private_ip]
}
