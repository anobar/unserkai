module "iam_users" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.11.1"

  for_each = { for user in local.iam_users : user.name => user }

  name = each.value.name

  create_iam_access_key         = false
  create_iam_user_login_profile = each.value.enable_iam_user_login_profile
  create_user                   = true
  force_destroy                 = false
  password_reset_required       = false
  password_length               = 20
  # chomp: remove last newline, cause: https://github.com/hashicorp/terraform/issues/20271
  pgp_key = chomp(var.pgp_key)

}


resource "aws_iam_user_policy" "ssm_cli_base" {
  for_each = { for user in local.iam_users : user.name => user }

  name = "ssm-cli-user-base-access-${each.value.name}"
  user = each.value.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AssumeSsmAccessRole"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/${each.value.name}"
      },
      {
        Sid = "CreateOwnVirtualMfaDevice"
        Effect = "Allow"
        Action = ["iam:CreateVirtualMFADevice"]
        Resource = "arn:aws:iam::${var.aws_account_id}:mfa/$${aws:username}"
      },
      {
        Sid = "ManageOwnMfaOnUser"
        Effect = "Allow"
        Action = ["iam:EnableMFADevice", "iam:DeactivateMFADevice", "iam:ListMFADevices", "iam:ResyncMFADevice", "iam:GetUser"]
        Resource = "arn:aws:iam::${var.aws_account_id}:user/${each.value.name}"
      },
      {
        Sid = "DeleteOwnVirtualMfaDevice"
        Effect = "Allow"
        Action = ["iam:DeleteVirtualMFADevice"]
        Resource = "arn:aws:iam::${var.aws_account_id}:mfa/$${aws:username}"
      }
    ]
  })
}
