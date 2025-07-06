resource "aws_iam_role" "control_plane_role" {
  name = "aseel-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "aseel-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "secret_manager_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "worker-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_security_group" "control_plane_sg" {
  name        = "k8s-control-plane-sg"
  description = "Security group for Kubernetes control plane instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kube API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all traffic within the vpc"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aseel-k8s-control-plane-sg"
  }
}

resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnets_id[0]
  vpc_security_group_ids      = [aws_security_group.control_plane_sg.id]
  associate_public_ip_address = true
  availability_zone           = var.availability_zone[0]
  iam_instance_profile        = aws_iam_instance_profile.control_plane_profile.name

  user_data = file("${path.module}/control_plane_userdata.sh")

  tags = {
    Name = "aseel-control-plane"
  }
}

resource "aws_eip" "control_plane_eip" {
  tags = {
    Name = "k8s-control-plane-eip"
  }
}

resource "aws_eip_association" "control_plane_eip_assoc" {
  instance_id   = aws_instance.control_plane.id
  allocation_id = aws_eip.control_plane_eip.id
}

resource "aws_launch_template" "worker_lt" {
  name_prefix   = "aseel-worker"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.control_plane_sg.id]
  }

  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "aseel-worker" #
    }
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                      = "k8s-worker-asg"
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = var.subnets_id
  health_check_type         = "EC2"

  launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "aseel-worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
