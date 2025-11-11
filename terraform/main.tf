# ✅ Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ✅ Get default VPC
data "aws_vpc" "default" {
  default = true
}

# ✅ Create Security Group for ELK + SSH
resource "aws_security_group" "elk_sg" {
  name        = "elk-sg"
  description = "Allow ELK and SSH access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "Kibana"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "Elasticsearch"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "Logstash"
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elk-sg"
  }
}

# ✅ Create ECR Repository for Sample App
resource "aws_ecr_repository" "sample_app_repo" {
  name                 = "real-time-log-analyzer"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "Real-Time-Log-Analyzer-ECR"
  }
}

# ✅ Launch EC2 Instance
resource "aws_instance" "elk_instance" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.elk_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

  # 🧠 user_data sets up Docker + Compose + pulls from ECR
  user_data = <<-EOF
    #!/bin/bash
    set -e
    yum update -y
    amazon-linux-extras install docker -y || yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose (v2 binary)
    COMPOSE_PATH="/usr/local/bin/docker-compose"
    if [ ! -f "$COMPOSE_PATH" ]; then
      echo "Installing Docker Compose..."
      curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o $COMPOSE_PATH
      chmod +x $COMPOSE_PATH
      ln -s $COMPOSE_PATH /usr/bin/docker-compose
    fi

    # Install AWS CLI (so docker can authenticate using IAM role)
    yum install -y awscli

    # Add 2GB swap for stability
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

    # Set kernel parameter for Elasticsearch
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf

    # Authenticate Docker to ECR (IAM role handles permissions)
    REGION="${var.region}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "Logging in to ECR at boot..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com || echo "ECR login failed"

    # Verify Docker installation
    docker --version
    docker-compose --version || echo "Docker Compose installation failed"

    # Optional: Restart for clean environment
    (sleep 10 && reboot) &
  EOF

  tags = {
    Name = "RealTime-Log-Analyzer"
  }
}

# # ✅ Outputs
# output "ecr_repo_url" {
#   value = aws_ecr_repository.sample_app_repo.repository_url
#   description = "ECR Repository URL for Sample App"
# }

# output "public_ip" {
#   value = aws_instance.elk_instance.public_ip
# }

# output "ssh_command" {
#   value = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.elk_instance.public_ip}"
# }

# output "kibana_url" {
#   value = "http://${aws_instance.elk_instance.public_ip}:5601"
# }
