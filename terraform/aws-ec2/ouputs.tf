output "control_plane_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.control_plane[0].public_ip
}

output "public_dns" {
  description = "Public IPv4 DNS"
  value       = aws_instance.control_plane[0].public_dns
}
