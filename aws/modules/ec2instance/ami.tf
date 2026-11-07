data "aws_ami" "ami" {
  count = length(var.ami_name_pattern) > 0 ? 1 : 0

  most_recent = true
  owners      = [var.ami_owner]
  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


data "aws_ami" "ubuntu_jammy" {
  owners      = ["099720109477"]
  most_recent = false
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20260503"]
  }
}
