variable "region" {
  description = "AWS region to deploy EC2"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "allowed_ip" {
  description = "Your public IP (for SSH and Kibana access)"
  type        = string
  default     = "0.0.0.0/0"
}
