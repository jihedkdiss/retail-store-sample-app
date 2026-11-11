################################################################################
# Synthetic traffic: runs the repo's Artillery scenario (src/load-generator)
# continuously against the application URL as a small Fargate service.
################################################################################

data "aws_region" "current" {}

locals {
  name = "${var.environment_name}-load-generator"

  # One Artillery run per minute, each starting `users_per_minute` virtual users
  # spread over that minute; repeated forever. Each virtual user walks the full
  # shop flow (home, catalog, every product, cart, checkout, delivery, payment).
  overrides = jsonencode({
    config = { phases = [{ duration = 60, arrivalCount = var.users_per_minute }] }
  })
  run_loop = "while true; do /home/node/artillery/bin/run run -q -t '${var.target_url}' --overrides '${local.overrides}' /scripts/scenario.yml; sleep 1; done"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.name}"
  retention_in_days = 3
  tags              = var.tags
}

resource "aws_iam_role" "execution" {
  name = "${local.name}-te"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "this" {
  name        = local.name
  description = "Load generator: outbound only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Reach the application URL and pull images"
  }

  tags = merge(var.tags, { Name = local.name })
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn

  volume {
    name = "scripts"
  }

  container_definitions = jsonencode([
    {
      # Copies scenario.yml and helpers.js from the repo's published image.
      name        = "setup"
      image       = "public.ecr.aws/aws-containers/retail-store-sample-utils:load-gen.${var.app_version}"
      essential   = false
      command     = ["bash", "-c", "cp /artillery/* /scripts"]
      mountPoints = [{ sourceVolume = "scripts", containerPath = "/scripts" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "setup"
        }
      }
    },
    {
      name        = "artillery"
      image       = "artilleryio/artillery:${var.artillery_version}"
      essential   = true
      entryPoint  = ["sh", "-c"]
      command     = [local.run_loop]
      mountPoints = [{ sourceVolume = "scripts", containerPath = "/scripts" }]
      dependsOn   = [{ containerName = "setup", condition = "SUCCESS" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "artillery"
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name            = "load-generator"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  tags = var.tags
}
