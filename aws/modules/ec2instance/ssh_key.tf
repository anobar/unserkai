resource "aws_key_pair" "ssh" {
  count      = local.enable_ssh_key ? 1 : 0
  key_name   = var.name
  public_key = var.ssh_public_key
}
