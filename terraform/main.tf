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
    set -e
    yum update -y

    # Install Docker
    amazon-linux-extras install docker -y || yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose (v2, newer + supported)
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Create 2GB Swap Memory (needed for ELK on t3.micro)
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

    # Verify installation
    # docker-compose version || echo "Docker Compose not installed properly"

    # Set kernel param for Elasticsearch
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf

    # Optional: Restart to ensure stability after setup
    (sleep 15 && reboot) &
  EOF


  tags = {
    Name = "RealTime-Log-Analyzer"
  }
}

# ✅ Output public IP
# output "elk_public_ip" {
#   value = aws_instance.elk_instance.public_ip
#   description = "Public IP of the ELK EC2 instance"
# }

# output "elk_ssh_command" {
#   value = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.elk_instance.public_ip}"
# }

# output "kibana_url" {
#   value = "http://${aws_instance.elk_instance.public_ip}:5601"
# }
