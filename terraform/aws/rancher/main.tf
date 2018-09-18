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
  vars {
    unique_name = "${var.unique_name}"
    public_domain = "${var.public_domain}"
  }
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

resource "aws_eip" "rancher" {
  instance = "${aws_instance.rancher.id}"
  vpc      = true
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

resource "aws_security_group_rule" "http-external" {
  type                     = "ingress"
  security_group_id        = "${aws_security_group.rancher.id}"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https-external" {
  type              = "ingress"
  security_group_id = "${aws_security_group.rancher.id}"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
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
  ttl     = "300"
  records = ["${aws_eip.rancher.public_ip}"]
}
