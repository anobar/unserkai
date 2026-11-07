locals {
  rules          = csvdecode(file("${path.module}/firewall_rules.csv"))
}
