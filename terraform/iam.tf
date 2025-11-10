# iam.tf — Attach IAM Role with ECR read access to EC2 instance

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ecr_role" {
  name               = "ec2-ecr-pull-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "ec2-ecr-pull-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-ecr-instance-profile"
  role = aws_iam_role.ec2_ecr_role.name
}
