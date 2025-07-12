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


resource "aws_security_group" "worker_sg" {
  name        = "k8s-worker-sg"
  description = "Security group for Kubernetes worker instances"
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

  ingress {
    description              = "Allow ALB to access port 31888"
    from_port                = 31888
    to_port                  = 31888
    protocol                 = "tcp"
    security_groups          = [aws_security_group.alb_sg.id]
  }
  ingress {
  description              = "Allow all traffic from control plane"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_groups          = [aws_security_group.control_plane_sg.id]
}

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aseel-k8s-worker-sg"
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
    security_groups             = [aws_security_group.worker_sg.id]
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

  lifecycle {
    create_before_destroy = true
  }

  target_group_arns = [aws_lb_target_group.polybot_tg.arn]

  #When you launch new EC2 instances in this Auto Scaling Group, automatically register them as targets in the specified target group (polybot_tg)


  tag {
    key                 = "Name"
    value               = "aseel-worker"
    propagate_at_launch = true
  }

}



# Security group for Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "aseel-polybot-alb-sg"
  description = "Allow HTTPS from internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "polybot-alb-sg"
  }
}

# Application Load Balancer (ALB)
#ALB is internet-facing, forwards traffic from port 443 (HTTPS) to 31888 (NodePort) on worker instances.
resource "aws_lb" "polybot_alb" {
  name               = "aseel-polybot-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnets_id

  tags = {
    Name = "polybot-alb"
  }
}

# Target Group
#Defines a group of instances (targets) that receive traffic from the ALB — in your case, the worker EC2 nodes.
resource "aws_lb_target_group" "polybot_tg" {
  name        = "aseel-polybot-tg"
  port        = 31888  #Port the worker nodes expose (NodePort)
  protocol    = "HTTP"  # Use HTTP between ALB and instances
  target_type = "instance" #Targets are EC2 instances (not IPs)
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTP"
    port                = "31888"
    path                = "/healthz"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }

  tags = {
    Name = "polybot-tg"
  }
}

# Listener for HTTPS (you need a valid ACM cert in the same region)'
#Creates a listener on the ALB — defines how incoming traffic is handled.

resource "aws_lb_listener" "polybot_https_listener" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.polybot_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.polybot_tg.arn
  }
}


# ACM Certificate (DNS validated)
#Requests a new SSL/TLS certificate from AWS ACM for a custom domain (like polybot-aseel-dev.fursa.click).
resource "aws_acm_certificate" "polybot_cert" {
  domain_name       = "polybot-aseel-dev.fursa.click"
  validation_method = "DNS"

  tags = {
    Name = "polybot-dev-cert"
  }
}

# Route 53 Record for ACM DNS validation
#Creates the required DNS record in Route 53 to prove you own the domain and complete ACM validation.
resource "aws_route53_record" "polybot_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.polybot_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

# Certificate validation resource
#Tells AWS to finalize the certificate after the DNS validation record has been created.
resource "aws_acm_certificate_validation" "polybot_cert_validation" {
  certificate_arn         = aws_acm_certificate.polybot_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.polybot_cert_validation : record.fqdn]
}

# Route 53 A record pointing to ALB
resource "aws_route53_record" "polybot_dns" {
  zone_id = var.route53_zone_id
  name    = "polybot-aseel-dev.fursa.click"
  type    = "A"

  alias {
    #It points your domain (like polybot-aseel-dev.fursa.click) to an AWS resource that doesn’t have a static IP — like an Application Load Balancer (ALB).
    name                   = aws_lb.polybot_alb.dns_name
    zone_id                = aws_lb.polybot_alb.zone_id
    evaluate_target_health = true
  }
}

