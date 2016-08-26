resource "aws_ecs_cluster" "main" {
  name = "terraformecstest11"
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
        "hostPort": 0
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

resource "aws_ecs_service" "outyet" {
  name            = "outyet"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.outyet.arn}"
  desired_count   = 3

  iam_role = "${aws_iam_role.ecs_service.arn}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.ecs_tg.arn}"
    container_name   = "outyet"
    container_port   = "8080"
  }

  depends_on = ["aws_iam_role_policy.ecs_service"]
}

######
# Create a new ALB things
######
resource "aws_alb" "ecs_alb" {
  name            = "alb-ecs"
  internal        = false
  security_groups = ["${aws_security_group.main_sg.id}"]
  subnets         = ["${aws_subnet.public_subnet.*.id}"]

  enable_deletion_protection = false

  tags {
    Name = "alb_ecs_setup"
  }
}

resource "aws_alb_target_group" "ecs_tg" {
  name     = "alb-ecs-thing"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.default.id}"
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.ecs_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs_tg.arn}"
    type             = "forward"
  }
}

######

# End ALB things

######

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
  subnet_id                   = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  vpc_security_group_ids      = ["${aws_security_group.main_sg.id}"]
  key_name                    = "${aws_key_pair.ssh_thing.key_name}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.test_profile.name}"
  user_data                   = "${data.template_file.ecs-setup.rendered}"

  tags {
    Name = "ecs-thing"
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
    Name = "ecs-vpc"
  }
}

variable "subnet_count" {
  default = 3
}

variable "aws_availability_zones" {
  default = "us-west-2a,us-west-2b,us-west-2c"
}

resource "aws_subnet" "public_subnet" {
  count                   = "${var.subnet_count}"
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true

  availability_zone = "${element(split(",",var.aws_availability_zones), count.index)}"

  tags {
    Name = "public_subnet_${count.index}"
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
  count          = "${var.subnet_count}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.r.id}"
}

resource "aws_security_group" "main_sg" {
  name        = "main_sg"
  description = "main_sg"
  vpc_id      = "${aws_vpc.default.id}"

  # probably a lot of rules that don't need to be here
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
    from_port = 0
    to_port   = 0
    protocol  = "tcp"
    self      = true
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
    Name = "main_sg"
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

output "rendered" {
  value = "${data.template_file.ecs-setup.rendered}"
}
