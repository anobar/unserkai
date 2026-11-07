/**
* AWS ACM Certificate
*
* This module creates a wildcard certificate and validates it via DNS.
*
*/

# SSL certificate
resource "aws_acm_certificate" "certificate" {
  domain_name       = "*.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    prevent_destroy = true # disable before destroying
  }
}

# create cname record for SSL certificate validation via DNS
resource "aws_route53_record" "certificate-cname" {
  zone_id = var.route53_public_hostedzone_id
  name    = tolist(aws_acm_certificate.certificate.domain_validation_options)[0].resource_record_name
  type    = "CNAME"
  ttl     = "30"
  records = [
    tolist(aws_acm_certificate.certificate.domain_validation_options)[0].resource_record_value,
  ]
}

# wait for aws validation of SSL certificate
resource "aws_acm_certificate_validation" "certificate" {
  certificate_arn = aws_acm_certificate.certificate.arn

  timeouts {
    create = "5m"
  }
}
