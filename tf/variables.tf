variable "env" {
   description = "Deployment environment"
   type        = string
}

variable "region" {
   description = "AWS region"
   type        = string
}

variable "ami_id" {
   description = "EC2 Ubuntu AMI"
   type        = string
}

variable "az" {
   description = "AWS Availability zone"
   type = list(string)
}

variable "key_name" {
  description = "Name of the EC2 Key Pair to allow SSH access to instances"
  type        = string
}

# EC2 instance type to use for the control plane
variable "control_plane_instance_type" {
  description = "Instance type for the control plane EC2 instance (e.g., t3.medium)"
  type        = string
}

