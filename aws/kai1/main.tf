locals {
  rules          = csvdecode(file("${path.module}/firewall_rules.csv"))
  name = "kai1"
}
