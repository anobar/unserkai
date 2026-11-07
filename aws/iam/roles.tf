resource "aws_iam_role_policy" "ssm_access" {
  for_each = { for user in local.iam_users : user.name => user }

  name = "start-session-on-created-instance-${each.value.name}"
  role = "ssm-session-access-${each.value.name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "StartSessionOnThisInstanceUsingDefaultShell"
        Effect = "Allow"
        Action = ["ssm:StartSession"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:document/SSM-SessionManagerRunShell"
        ]
      },
      {
        Sid = "OpenOwnSessionDataChannel"
        Effect = "Allow"
        Action = ["ssmmessages:OpenDataChannel"]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:session/$${aws:userid}-*"
      },
      {
        Sid = "ManageOwnSessions"
        Effect = "Allow"
        Action = ["ssm:TerminateSession", "ssm:ResumeSession"]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:session/$${aws:userid}-*"
      },
      {
        Sid = "ReadSessionAndInstanceStatus"
        Effect = "Allow"
        Action = ["ssm:DescribeSessions", "ssm:GetConnectionStatus", "ssm:DescribeInstanceInformation", "ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_ssh_access" {
  for_each = { for user in local.iam_users : user.name => user }

  name = "start-ssh-session-on-created-instance-${each.value.name}"
  role = "ssm-session-access-${each.value.name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "StartSshSessionOnThisInstance"
        Effect = "Allow"
        Action = ["ssm:StartSession"]
        Resource = [
          "arn:aws:ssm:eu-central-1::document/AWS-StartSSHSession"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy" "ssm_start_session" {
  for_each = { for user in local.iam_users : user.name => user }
  name = "start-session-on-created-instance-${each.value.name}"
  role = "ssm-session-access-${each.value.name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "StartSessionOnThisInstanceUsingDefaultShell"
        Effect = "Allow"
        Action = ["ssm:StartSession"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${var.aws_account_id}:instance/*",
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:document/SSM-SessionManagerRunShell"
        ]
      },
      {
        Sid = "OpenOwnSessionDataChannel"
        Effect = "Allow"
        Action = ["ssmmessages:OpenDataChannel"]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:session/$${aws:userid}-*"
      },
      {
        Sid = "ManageOwnSessions"
        Effect = "Allow"
        Action = ["ssm:TerminateSession", "ssm:ResumeSession"]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:session/$${aws:userid}-*"
      },
      {
        Sid = "ReadSessionAndInstanceStatus"
        Effect = "Allow"
        Action = ["ssm:DescribeSessions", "ssm:GetConnectionStatus", "ssm:DescribeInstanceInformation", "ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_start_stop_policy" {
  for_each = { for user in local.iam_users : user.name => user }
  name        = "EC2StartStopPolicy"
  role        = "ssm-session-access-${each.value.name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "ssm_session_access" {
  for_each = { for user in local.iam_users : user.name => user }

  name = "ssm-session-access-${each.value.name}"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "AllowOnlyNamedUserWithMfa"
      Effect = "Allow"
      Principal = { AWS =  "arn:aws:iam::${var.aws_account_id}:user/${each.value.name}"}
      Action = "sts:AssumeRole"
      Condition = {
        Bool = { "aws:MultiFactorAuthPresent" = "true" }
        NumericLessThanEquals = { "aws:MultiFactorAuthAge" = "3600" }
      }
    }]
  })
}
