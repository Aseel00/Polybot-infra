# AWS region to deploy the resources in
variable "region" {
  description = "AWS region for the Kubernetes control plane resources"
  type        = string
}

# AMI ID for the EC2 instance
variable "ami_id" {
  description = "AMI ID used for the control plane EC2 instance. Should have kubeadm, kubelet, and docker/containerd pre-installed"
  type        = string
}

# EC2 instance type for the control plane
variable "instance_type" {
  description = "Instance type for the Kubernetes control plane (e.g., t3.medium)"
  type        = string
}

# EC2 key pair name for SSH access
variable "key_name" {
  description = "Name of the existing AWS EC2 Key Pair to allow SSH access to the instance"
  type        = string
}

# VPC where the control plane instance will be deployed
variable "vpc_id" {
  description = "VPC ID where the control plane instance will be deployed"
  type        = string
}

# Subnet where the control plane instance will reside
variable "subnets_id" {
  description = "Subnet ID for the control plane EC2 instance"
  type        = list(string)
}

# Security group(s) for the control plane instance
#variable "security_group_ids" {
 # description = "List of security group IDs to associate with the control plane EC2 instance"
  #type        = list(string)
#}

variable "availability_zone" {
  type = list(string)
}

variable "vpc_cidr" {
  type = string
}

variable "route53_zone_id" {
  description = "Hosted Zone ID for fursa.click"
  type        = string
}
