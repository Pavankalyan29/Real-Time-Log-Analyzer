output "public_ip" {
  value = aws_instance.elk_instance.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.elk_instance.public_ip}"
}

output "kibana_url" {
  value = "http://${aws_instance.elk_instance.public_ip}:5601"
}
