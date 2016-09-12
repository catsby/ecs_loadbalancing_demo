output "instance_ips" {
  value = ["${aws_instance.ecs.*.public_dns}"]
}

output "alb_dns" {
  value = "${aws_alb.ecs_alb.dns_name}"
}
