resource "aws_iam_role" "k8s_role" {
  name = "k8sEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "k8s_ssm_policy" {
  name = "k8sSSMPolicy"
  role = aws_iam_role.k8s_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DescribeInstanceInformation",
          "ssm:SendCommand",
          "ssm:StartSession",
          "ssm:TerminateSession"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_instance_profile" "k8s_profile" {
  name = "k8sInstanceProfile"
  role = aws_iam_role.k8s_role.name
}


# MASTER NODE ############################################


resource "aws_instance" "master" {
  ami                    = "ami-00ca570c1b6d79f36"  # Amazon Linux 2 x86_64
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  security_groups        = var.security_group_id
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.k8s_profile.name

  user_data = file("userdata/master.sh")

  tags = {
    Name = "k8s-master"
  }
}

# WORKER NODES (2) ############################################


resource "aws_instance" "worker" {
  count                  = 2
  ami                    = "ami-00ca570c1b6d79f36"  # Amazon Linux 2
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  security_groups        = var.security_group_id
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.k8s_profile.name

  user_data = file("userdata/worker.sh")

  tags = {
    Name = "k8s-worker-${count.index + 1}"
  }

  depends_on = [aws_instance.master]  # Ensure master is created first
}
