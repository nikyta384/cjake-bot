resource "aws_ecs_cluster" "cluster" {
  name = "${var.project_prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_prefix}"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_prefix}-task"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn      = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([
    # --- ChromaDB container ---
    {
      name         = "chromadb"
      image        = "ghcr.io/chroma-core/chroma:latest"
      essential    = true
      portMappings = [
        { containerPort = 8000, hostPort = 8000, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.project_prefix}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "chromadb"
        }
      }
    },

    # --- App collector container ---
    {
      name         = "app"
      image        = "${aws_ecr_repository.app.repository_url}"
      essential    = true
      secrets = [
      {
        name      = "OPENAI_API_KEY"
        valueFrom = aws_secretsmanager_secret.openai.arn
      },
      {
        name      = "API_ID"
        valueFrom = aws_secretsmanager_secret.tg_api_id.arn
      },
      {
        name      = "BOT_TOKEN"
        valueFrom = aws_secretsmanager_secret.bot_token.arn
      },
      {
        name      = "API_HASH"
        valueFrom = aws_secretsmanager_secret.tg_api_id.arn
      },
      {
        name      = "TG_ARCHIVE_PASS"
        valueFrom = aws_secretsmanager_secret.tg_archive_pass.arn
      }
    ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.project_prefix}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "app-collector"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "service" {
  name            = "${var.project_prefix}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1
  force_new_deployment = true

  network_configuration {
    subnets          = [aws_subnet.public_a.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}
