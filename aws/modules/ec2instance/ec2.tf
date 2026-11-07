resource "aws_instance" "this" {
  ami                  = local.ec2_ami_id
  instance_type        = var.instance_type
  key_name             = local.enable_ssh_key ? var.name : null
  associate_public_ip_address = false
  availability_zone            = var.availability_zone
  iam_instance_profile = aws_iam_instance_profile.ec2.id
  monitoring           = true
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  user_data            = var.user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted = true
    tags = merge(var.volume_tags, { Name = var.name })
  }

  subnet_id = local.instance_subnet_id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  tags = merge(
    var.ec2_tags,
    {
      Name = var.name
      SSMAccess = "true"
    }
  )

  lifecycle {
    ignore_changes = [
      user_data,
      ami
    ]
  }
}
