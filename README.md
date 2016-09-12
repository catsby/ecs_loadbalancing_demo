# ECS + ALB/ELB

This repo contains two examples of using Terraform to configure [Amazon Elastic
Container Service][ecs]; one for use with [Classic Elastic Load Balancer][elb], and a second
one using the newer [Application Load Balancer][alb]. Each example is in it's own
folder, `elb_classic` and `alb`, respectively.

###NOTE

Using either of these will spin up *real* infrastructure on Amazon. You are
responsible for any charges that occur. 

## Steps:

1. `cd` into the desired folder
1. uncomment and configure your access key / secret in the `provider` block
1. `terraform plan` to preview the changes
1. `terraform apply`
1. check out https://us-west-2.console.aws.amazon.com/ecs/home and see the
   specifics of your ECS cluster
1. for Classic, you should see that one count of the task could not be placed
   due to the restriction of Service+Port+Instance
1. for the new ALB, you'll see all 3 tasks running, with one ECS Instance
   running two counts of the task

The DNS entry for the respecitve load balaner will be output and you can hit
that directly. To hit an instance specifically, you'll need the Instance IP and
to know the port. For the classic example that's `8080`. For the ALB example,
you'll need to look up which dynamic port it was given in the AWS console. 

Both setups create about the same resources, the main difference being the `aws_alb`
and `aws_alb_target_group` resources.


**Requirements:**

- AWS credentials either in the environment, or edit the `provider` block
- an ssh key setup at `~/.ssh/id_rsa2.pub`

[ecs]: https://aws.amazon.com/ecs/?hp=tile
[elb]: http://docs.aws.amazon.com/elasticloadbalancing/latest/classic/introduction.html
[alb]: http://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html
