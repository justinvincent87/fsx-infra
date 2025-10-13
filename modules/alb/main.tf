# ALB Module


variable "name" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "target_instance_ids" { type = list(string) }
variable "tags" { type = map(string) }

variable "type" {
  description = "Type of ALB: web, api, or auth"
  type        = string
}
variable "web_port" {
  description = "Port web is running on EC2 (for web/api)"
  default     = 80
}
variable "auth_port" {
  description = "Port auth is running on EC2 (for auth)"
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



# Target group and attachment for web
resource "aws_lb_target_group" "web" {
  count       = var.type == "web" ? 1 : 0
  name        = "${var.name}-tg"
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
}
resource "aws_lb_target_group_attachment" "web" {
  count            = var.type == "web" ? 1 : 0
  target_group_arn = aws_lb_target_group.web[0].arn
  target_id        = var.target_instance_ids[0]
  port             = var.web_port
}
resource "aws_lb_listener" "web" {
  count             = var.type == "web" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web[0].arn
  }
}

# Target group and attachment for auth
resource "aws_lb_target_group" "auth" {
  count       = var.type == "auth" ? 1 : 0
  name        = "${var.name}-tg"
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
}
resource "aws_lb_target_group_attachment" "auth" {
  count            = var.type == "auth" ? 1 : 0
  target_group_arn = aws_lb_target_group.auth[0].arn
  target_id        = var.target_instance_ids[0]
  port             = var.auth_port
}
resource "aws_lb_listener" "auth" {
  count             = var.type == "auth" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth[0].arn
  }
}

# Target group and attachments for api
resource "aws_lb_target_group" "api" {
  count       = var.type == "api" ? 1 : 0
  name        = "${var.name}-tg"
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
}
resource "aws_lb_target_group_attachment" "api" {
  count            = var.type == "api" ? length(var.target_instance_ids) : 0
  target_group_arn = aws_lb_target_group.api[0].arn
  target_id        = var.target_instance_ids[count.index]
  port             = var.web_port
}
resource "aws_lb_listener" "api" {
  count             = var.type == "api" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }
}

