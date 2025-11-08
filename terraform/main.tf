# ✅ Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
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

# ✅ Get default VPC
data "aws_vpc" "default" {
  default = true
}

# ✅ Launch EC2 Instance
resource "aws_instance" "elk_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.elk_sg.id]
  associate_public_ip_address = true

  # 🧠 user_data runs once on boot to setup Docker + Compose + ELK
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Add docker-compose to PATH for all users
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Verify Docker Compose installation
    docker-compose --version > /home/ec2-user/compose-version.log 2>&1


    # Required for Elasticsearch
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf

    # ---------------------------
    # Add ec2-user to Docker group
    # ---------------------------
    usermod -aG docker ec2-user
  EOF

  tags = {
    Name = "RealTime-Log-Analyzer"
  }
}

# ✅ Output public IP
output "elk_public_ip" {
  value = aws_instance.elk_instance.public_ip
  description = "Public IP of the ELK EC2 instance"
}

output "elk_ssh_command" {
  value = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.elk_instance.public_ip}"
}

output "kibana_url" {
  value = "http://${aws_instance.elk_instance.public_ip}:5601"
}
