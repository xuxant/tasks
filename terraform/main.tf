######### Providers Config #######
provider "aws" {
  region = var.AWS_REGION
}

terraform {
  backend "s3" {
    bucket = "terraform-state-bck"
    region = "ap-northeast-1"
    key    = "demo/infra/statefile"
  }
}

######### VPC ############

data "aws_availability_zones" "available" {
  state = "available"
}


resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(
    var.tags,
    { Name = var.name }
  )
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    var.tags,
    { Name = var.name }
  )
}

resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 6, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index % 3]
  tags = merge(
    var.public_subnet_tags,
    var.tags,
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
    }
  )
}

resource "aws_subnet" "private_subnet" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, 3 + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index % 3]
  tags = merge(
    var.private_subnet_tags,
    var.tags,
    {
      Name = "${var.environment}-private-subnet-${count.index + 1}"
    }
  )
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  count         = 3
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
  tags = merge(
    var.tags,
    { Name = "${var.name}-${data.aws_availability_zones.available.names[count.index % 3]}" }
  )
}


resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    var.tags,
    { Name = "${var.environment}-public-route-table" }
  )
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = 3
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.this.id
  tags = merge(
    var.tags,
    { Name = "${var.environment}-private-route-table" }
  )
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[0].id
}

# Associate private route table with private subnets
resource "aws_route_table_association" "private_subnet_association" {
  count          = 3
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}


######## ECS ############

data "aws_region" "current" {}

data "aws_partition" "current" {
}


data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    effect = "Allow"
    resources = [
      aws_cloudwatch_log_group.ecs.arn,
      "${aws_cloudwatch_log_group.ecs.arn}:*"
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}


data "aws_iam_policy_document" "task_execution_permissions" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = var.name
  retention_in_days = var.log_retention_in_days
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy" "task_execution" {
  name_prefix = "${var.name}-task-execution"
  role        = aws_iam_role.execution.id
  policy      = data.aws_iam_policy_document.task_execution_permissions.json
}

resource "aws_iam_role" "ecs" {
  name_prefix        = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

resource "aws_iam_role_policy" "log_agent" {
  name_prefix = "${var.name}-log-permissions"
  role        = aws_iam_role.ecs.id
  policy      = data.aws_iam_policy_document.task_permissions.json
}

resource "aws_security_group" "alb" {
  name_prefix = "ecs_loadbalancer_tyk"
  description = "Security Group for Loadbalancer"
  vpc_id      = aws_vpc.this.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Port 80 ingress"
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Port 443 ingress"
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "egress"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_security_group" "app" {
  name_prefix = "app"
  description = "Security Group for app external access."
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App port"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "app-access-sg"
  }

}

resource "aws_lb" "app" {
  name               = "${var.name}-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public_subnet.*.id
}

resource "aws_lb_target_group" "app" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path = "/"
  }
}


resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_cluster" "this" {
  name = var.name
  setting {
    name  = "containerInsights"
    value = var.container_insights ? "enabled" : "disable"
  }

  tags = {
    "Name" = var.name
  }
}

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = var.service_name
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.execution.arn


  container_definitions = jsonencode(
    [
      {
        "cpu" : var.container_cpu,
        "image" : var.image,
        "memory" : var.container_memory,
        "name" : var.service_name
        "portMappings" : [
          {
            "containerPort" : var.container_port,
          }
        ]
      }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  depends_on                         = [aws_lb.app]
  name                               = var.name
  cluster                            = aws_ecs_cluster.this.id
  launch_type                        = "FARGATE"
  deployment_maximum_percent         = "200"
  deployment_minimum_healthy_percent = "75"
  desired_count                      = var.desired_count
  network_configuration {
    subnets         = aws_subnet.private_subnet.*.ids
    security_groups = [aws_security_group.app.id]
  }

  task_definition = "${aws_ecs_task_definition.ecs_task.family}:${max(aws_ecs_task_definition.ecs_task.revision, aws_ecs_task_definition.ecs_task.revision)}"

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }
}

######## Auto Scaling ##########

resource "aws_appautoscaling_target" "this" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "app_to_memory" {
  name               = "scale-to-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "app_to_cpu" {
  name               = "scale-to-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}
