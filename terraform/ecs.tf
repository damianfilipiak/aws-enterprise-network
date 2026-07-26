resource "aws_ecs_cluster" "office_sim" {
  name = "office-sim-cluster"
}

resource "aws_ecs_task_definition" "office_sim_task" {
  family                   = "office-sim-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "office-sim"
      image     = "public.ecr.aws/amazonlinux/amazonlinux:2"
      essential = true
      command   = ["/bin/sh","-c","while true; do curl -sfS https://example.com >/dev/null || true; sleep 30; done"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/office-sim"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "office-sim"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "office_sim_logs" {
  name              = "/ecs/office-sim"
  retention_in_days = 14
}

resource "aws_ecs_service" "office_sim_service" {
  name            = "office-sim-service"
  cluster         = aws_ecs_cluster.office_sim.id
  task_definition = aws_ecs_task_definition.office_sim_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.private_user_subnet_a.id, aws_subnet.private_user_subnet_b.id]
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_attach]
}
