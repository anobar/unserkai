resource "aws_iam_role" "ec2-role" {
  #name = "${var.name}-ec2-role"
  name = var.name
  path = "/terraform/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2" {
  #name = "${var.name}-ec2-instance-profile"
  name = var.name
  path = "/terraform/"
  role = aws_iam_role.ec2-role.name
}

resource "aws_iam_role_policy_attachment" "enable-ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2-role.name
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  count      = length(var.ec2_role_policy_attachments)
  policy_arn = var.ec2_role_policy_attachments[count.index]
  role       = aws_iam_role.ec2-role.name
}
