resource "aws_ecs_cluster" "main" {
  name = "elb_ecs_classice"
}

resource "aws_ecs_task_definition" "outyet" {
  family = "outyet_service"

  container_definitions = <<DEFINITION
[
  {
    "cpu": 128,
    "essential": true,
    "image": "goexample/outyet",
    "memory": 128,
    "name": "outyet",
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080
      }
    ]
  }
]
DEFINITION
}

resource "aws_iam_role" "ecs_service" {
  name = "EcsService"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {"AWS": "*"},
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "EcsService"
  role = "${aws_iam_role.ecs_service.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*",
        "ec2:*",
        "ecs:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_elb" "main" {
  subnets         = ["${aws_subnet.tf_test_subnet.id}"]
  security_groups = ["${aws_security_group.tf_test_sg_ssh.id}"]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_ecs_service" "outyet" {
  name            = "outyet"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.outyet.arn}"
  desired_count   = 3
  iam_role        = "${aws_iam_role.ecs_service.arn}"

  load_balancer {
    elb_name       = "${aws_elb.main.id}"
    container_name = "outyet"
    container_port = "8080"
  }

  depends_on = ["aws_iam_role_policy.ecs_service"]
}

data "template_file" "ecs-setup" {
  template = "${file("${path.module}/ecs.sh.tpl")}"

  vars {
    cluster = "${aws_ecs_cluster.main.name}"
  }
}

resource "aws_instance" "ecs" {
  count                       = 2
  ami                         = "ami-2d1bce4d"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.tf_test_subnet.id}"
  vpc_security_group_ids      = ["${aws_security_group.tf_test_sg_ssh.id}"]
  key_name                    = "${aws_key_pair.ssh_thing.key_name}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.test_profile.name}"
  user_data                   = "${data.template_file.ecs-setup.rendered}"

  tags {
    Name = "cts-ecs-thing"
  }
}

######
#BASE
######
provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "default"
  }
}

resource "aws_subnet" "tf_test_subnet" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "tf_test_subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "main"
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "aws_route_table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.tf_test_subnet.id}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_security_group" "tf_test_sg_ssh" {
  name        = "tf_test_sg_ssh"
  description = "tf_test_sg_ssh"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 80
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "tf_test_sg_ssh"
  }
}

resource "aws_key_pair" "ssh_thing" {
  key_name   = "tf-testing-c"
  public_key = "${file("~/.ssh/id_rsa2.pub")}"
}

output "ip" {
  value = ["${aws_instance.ecs.*.public_dns}"]
}

resource "aws_iam_instance_profile" "test_profile" {
  name  = "test_profile"
  roles = ["${aws_iam_role.ecs_service.name}"]
}

output "elb_dns" {
  value = "${aws_elb.main.dns_name}"
}

output "rendered" {
  value = "${data.template_file.ecs-setup.rendered}"
}
