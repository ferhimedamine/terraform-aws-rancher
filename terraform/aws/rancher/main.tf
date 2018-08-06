provider "aws" {
  version = "~> 1.24.0"
  region  = "${var.region}"

  assume_role {
    role_arn     = "${var.assume_role_arn}"
    session_name = "rancher"
  }
}

data "aws_route53_zone" "public_zone" {
  name         = "${var.public_domain}"
  private_zone = false
}

data "aws_vpc" "selected" {
  default = true
}

data "aws_subnet_ids" "subnets" {
  vpc_id = "${data.aws_vpc.selected.id}"
}

data "aws_ami" "coreos" {
  most_recent = true

  owners = ["595879546273"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["CoreOS-${var.coreos_channel}-*"]
  }
}

data "template_file" "rancher" {
  template = "${file("${path.module}/scripts/rancher.yaml.tmpl")}"
}

data "ct_config" "rancher" {
  content      = "${data.template_file.rancher.rendered}"
  platform     = "ec2"
  pretty_print = false
  snippets     = ["${var.rancher_clc_snippets}"]
}

resource "tls_private_key" "rancher_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.unique_name}"
  public_key = "${tls_private_key.rancher_key.public_key_openssh}"
}

resource "aws_lb" "rancher_external" {
  name                             = "${var.unique_name}"
  subnets                          = ["${data.aws_subnet_ids.subnets.ids}"]
  security_groups                  = ["${aws_security_group.rancher_lb.id}"]
  internal                         = false
  idle_timeout                     = 4000
  load_balancer_type               = "application"
  enable_cross_zone_load_balancing = false

  tags {
    Name = "${var.unique_name}"
  }
}

resource "aws_lb_target_group_attachment" "rancher" {
  target_group_arn = "${aws_lb_target_group.rancher.arn}"
  target_id        = "${aws_instance.rancher.id}"
  port             = 443
}

resource "aws_lb_target_group" "rancher" {
  name     = "${var.unique_name}"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${data.aws_vpc.selected.id}"

  health_check {
    protocol            = "HTTPS"
    path                = "/"
    timeout             = 5
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = 200
  }
  stickiness {
    type = "lb_cookie"
    enabled = true
  }
}

resource "aws_lb_listener" "rancher-external" {
  load_balancer_arn = "${aws_lb.rancher_external.arn}"
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${aws_acm_certificate.cert.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.rancher.arn}"
    type             = "forward"
  }
}

resource "aws_ebs_volume" "rancher-etcd" {
  availability_zone = "${var.region}a"
  size              = "${var.volume_size}"
  snapshot_id       = "${var.etcd_ebs_snapshot_id}"

  tags {
    Name = "rancher-etcd.${var.unique_name}"
  }

  tags {
    Snapshot = "true"
  }
}

resource "aws_volume_attachment" "rancher-etcd" {
  # The device_name will be different on runtime
  # The device on linux will depend on the type of the instance in AWS
  device_name = "/dev/sdf"

  volume_id    = "${aws_ebs_volume.rancher-etcd.id}"
  instance_id  = "${aws_instance.rancher.id}"
  force_detach = true
}

resource "aws_instance" "rancher" {
  ami                         = "${data.aws_ami.coreos.image_id}"
  availability_zone           = "${var.region}a"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.unique_name}"
  security_groups             = ["${aws_security_group.rancher.name}"]
  associate_public_ip_address = false
  monitoring                  = true
  user_data                   = "${data.ct_config.rancher.rendered}"

  root_block_device = {
    volume_type           = "gp2"
    volume_size           = "${var.volume_size}"
    delete_on_termination = true
  }

  tags {
    Name = "${var.unique_name}"
  }
}

resource "aws_security_group" "rancher_lb" {
  name        = "${var.unique_name}-lb"
  description = "Security group for rancher"

  tags = {
    Name = "${var.unique_name}-lb"
  }
}

resource "aws_security_group_rule" "rancher_egress_lb" {
  type              = "egress"
  security_group_id = "${aws_security_group.rancher_lb.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https-external" {
  type              = "ingress"
  security_group_id = "${aws_security_group.rancher_lb.id}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "rancher" {
  name        = "${var.unique_name}"
  description = "Security group for rancher"

  tags = {
    Name = "${var.unique_name}"
  }
}

resource "aws_security_group_rule" "rancher_egress" {
  type              = "egress"
  security_group_id = "${aws_security_group.rancher.id}"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "http-internal" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.rancher.id}"
  source_security_group_id = "${aws_security_group.rancher_lb.id}"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "rancher-ssh-external" {
  type              = "ingress"
  security_group_id = "${aws_security_group.rancher.id}"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_route53_record" "rancher" {
  zone_id = "${data.aws_route53_zone.public_zone.zone_id}"
  name    = "${var.unique_name}"
  type    = "A"

  alias {
    name                   = "${aws_lb.rancher_external.dns_name}"
    zone_id                = "${aws_lb.rancher_external.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.unique_name}.${var.public_domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.public_zone.zone_id}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}
