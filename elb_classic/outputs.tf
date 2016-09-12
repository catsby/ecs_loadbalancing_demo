output "elb_dns" {
  value = "${aws_elb.main.dns_name}"
}

output "instanceips" {
  value = ["${aws_instance.ecs.*.public_dns}"]
}
