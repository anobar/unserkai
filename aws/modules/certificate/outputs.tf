output "certificate" {
  value       = aws_acm_certificate.certificate
  description = "certificate object"
}
output "arn" {
  value       = aws_acm_certificate.certificate.arn
  description = "certificate arn"
}
