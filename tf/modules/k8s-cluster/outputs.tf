output "control_plane_elastic_ip" {
  value = aws_eip.control_plane_eip.public_ip
  description = "Elastic IP address of the control plane"
}
