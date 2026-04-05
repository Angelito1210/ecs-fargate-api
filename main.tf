provider "aws" {
  region = "eu-west-1"
}

# Creamos el repositorio en ECR para guardar nuestra imagen Docker
resource "aws_ecr_repository" "api_repo" {
  name                 = "angel-api-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Output para saber la URL de nuestro repositorio
output "ecr_repository_url" {
  value = aws_ecr_repository.api_repo.repository_url
}

# ==========================================
# 1. RED Y SEGURIDAD (Usamos la VPC por defecto)
# ==========================================
resource "aws_default_vpc" "default" {}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "angel-api-ecs-sg"
  description = "Permitir trafico HTTP al puerto 8080"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 2. CLUSTER ECS Y ROLES IAM
# ==========================================
resource "aws_ecs_cluster" "main" {
  name = "angel-api-cluster"
}

# Rol para que ECS pueda descargar tu imagen de ECR y crear logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRoleAngel"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==========================================
# 3. DEFINICIÓN DE LA TAREA Y SERVICIO FARGATE
# ==========================================
resource "aws_ecs_task_definition" "api_task" {
  family                   = "angel-api-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU (lo mínimo y más barato)
  memory                   = "512" # 512 MB de RAM
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

container_definitions = jsonencode([{
    name      = "angel-api-container"
    image     = "${aws_ecr_repository.api_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    # AÑADE ESTO:
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/angel-api"
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "ecs"
        "awslogs-create-group"  = "true"
      }
    }
  }])
}

resource "aws_ecs_service" "api_service" {
  name            = "angel-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_task.arn
  desired_count   = 1 # Queremos que siempre haya 1 contenedor encendido
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}
