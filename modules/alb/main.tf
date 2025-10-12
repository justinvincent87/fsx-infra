# ALB Module


variable "name" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "target_instance_ids" { type = list(string) }
variable "tags" { type = map(string) }
variable "web_port" {
  description = "Port web is running on EC2"
  default     = 80
}
variable "auth_port" {
  description = "Port Keycloak is running on EC2"
  default     = 8080
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "web" {
  name        = "${var.name}-web-tg"
  port        = var.web_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = var.tags
}

resource "aws_lb_target_group" "auth" {
  name        = "${var.name}-auth-tg"
  port        = var.auth_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = var.tags
}

resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "auth_http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 81
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }
}

resource "aws_lb_target_group_attachment" "web" {
  count            = length(var.target_instance_ids) > 0 ? 1 : 0
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = var.target_instance_ids[0]
  port             = var.web_port
}

resource "aws_lb_target_group_attachment" "auth" {
  count            = length(var.target_instance_ids) > 1 ? 1 : 0
  target_group_arn = aws_lb_target_group.auth.arn
  target_id        = var.target_instance_ids[1]
  port             = var.auth_port
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}
