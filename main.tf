terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16"
    }
  }
  backend "s3" {}
}


# S3 BUCKET

resource "aws_s3_bucket" "bucket" {
  bucket_prefix = var.PRE
  force_destroy = true
  tags = {
    Name = "${var.PRE}bucket"
    Owner = var.OWNER
  }
}

resource "aws_s3_bucket_cors_configuration" "bucket_cors" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_methods = ["HEAD", "PUT", "POST"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    expose_headers  = []
  }
}


output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket_domain_name
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [var.AWS_PA_USER]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

# VPC

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "${var.PRE}vpc"
    Owner = var.OWNER
  }
}

output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

# Security Groups

resource "aws_security_group" "alb_access" {
  name        = "${var.PRE}sg-alb"
  description = "Allow access on port 80"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "port 80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.PRE}sg-alb"
    Owner = var.OWNER
  }
}

output "alb_sg_id" {
  value = aws_security_group.alb_access.id
}

resource "aws_security_group" "s3_app_access" {
  name        = "${var.PRE}sg-s3-app"
  description = "Allow access on port 5000"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "port 5000"
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    security_groups = [aws_security_group.alb_access.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.PRE}sg-s3-app"
    Owner = var.OWNER
  }
}

output "s3_app_access_sg_id" {
  value = aws_security_group.s3_app_access.id
}

resource "aws_security_group" "db_app_access" {
  name        = "${var.PRE}sg-db-app"
  description = "Allow access on port 8000"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "port 8000"
    from_port        = 8000
    to_port          = 8000
    protocol         = "tcp"
    security_groups = [aws_security_group.alb_access.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.PRE}sg-db-app"
    Owner = var.OWNER
  }
}

output "db_app_access_sg_id" {
  value = aws_security_group.db_app_access.id
}

resource "aws_security_group" "rds_access" {
  name        = "${var.PRE}sg-rds"
  description = "Allow access on port 5432 to db app sg"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "port 5432"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups = [aws_security_group.db_app_access.id]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.PRE}sg-rds"
    Owner = var.OWNER
  }
}


# Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.PRE}gw"
    Owner = var.OWNER
  }
}

# Route Tables & Subnets, with NAT Gateway between them

resource "aws_route_table" "rt_igw" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.PRE}rt-igw"
    Owner = var.OWNER
  }
}

resource "aws_route_table" "rt_nat" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.PRE}rt-nat"
    Owner = var.OWNER
  }
}

# SUBNETS

resource "aws_subnet" "sn_pub_az1" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.AWS_REGION}a"

  tags = {
    Name = "${var.PRE}sn-pub-az1"
    Owner = var.OWNER
  }
}

resource "aws_subnet" "sn_pub_az2" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${var.AWS_REGION}b"

  tags = {
    Name = "${var.PRE}sn-pub-az2"
    Owner = var.OWNER
  }
}

resource "aws_subnet" "sn_prv_az1" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "${var.AWS_REGION}a"

  tags = {
    Name = "${var.PRE}sn-prv-az1"
    Owner = var.OWNER
  }
}

output "sn_prv_az1_id" {
  value = aws_subnet.sn_prv_az1.id
}

resource "aws_subnet" "sn_prv_az2" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "${var.AWS_REGION}b"

  tags = {
    Name = "${var.PRE}sn-prv-az2"
    Owner = var.OWNER
  }
}

output "sn_prv_az2_id" {
  value = aws_subnet.sn_prv_az2.id
}

resource "aws_route_table_association" "sn_pub_az1_rt_assoc" {

  depends_on = [
    aws_vpc.main_vpc,
    aws_subnet.sn_pub_az1,
    aws_route_table.rt_igw,
  ]

  subnet_id      = aws_subnet.sn_pub_az1.id
  route_table_id = aws_route_table.rt_igw.id
}

resource "aws_route_table_association" "sn_pub_az2_rt_assoc" {

  depends_on = [
    aws_vpc.main_vpc,
    aws_subnet.sn_pub_az2,
    aws_route_table.rt_igw,
  ]

  subnet_id      = aws_subnet.sn_pub_az2.id
  route_table_id = aws_route_table.rt_igw.id
}

resource "aws_route_table_association" "sn_prv_az1_rt_assoc" {

  depends_on = [
    aws_vpc.main_vpc,
    aws_subnet.sn_prv_az1,
    aws_route_table.rt_nat,
    aws_nat_gateway.nat
  ]

  subnet_id      = aws_subnet.sn_prv_az1.id
  route_table_id = aws_route_table.rt_nat.id
}

resource "aws_route_table_association" "sn_prv_az2_rt_assoc" {

  depends_on = [
    aws_vpc.main_vpc,
    aws_subnet.sn_prv_az2,
    aws_route_table.rt_nat,
    aws_nat_gateway.nat
  ]

  subnet_id      = aws_subnet.sn_prv_az2.id
  route_table_id = aws_route_table.rt_nat.id
}

# Creating an Elastic IP for the NAT Gateway!
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  depends_on = [
    aws_eip.nat_eip
  ]

  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.sn_pub_az1.id
  tags = {
    Name = "${var.PRE}nat"
    Owner = var.OWNER
  }
}


resource "aws_db_subnet_group" "rds_sn_group" {
    name = "${var.PRE}rds-sn-group"
    description = "RDS sn group"
    subnet_ids = ["${aws_subnet.sn_prv_az1.id}", "${aws_subnet.sn_prv_az2.id}"]
}

# RDS

resource "aws_db_instance" "rds" {
  depends_on = [aws_db_subnet_group.rds_sn_group]

  allocated_storage    = 20
  db_name              = "crud"
  engine               = "postgres"
  engine_version       = "14.3"
  instance_class       = "db.t3.micro"
  username             = "postgres"
  password             = var.AWS_RDS_PASS
  port                 = 5432
  skip_final_snapshot  = true
  availability_zone = "${var.AWS_REGION}a"
  db_subnet_group_name = aws_db_subnet_group.rds_sn_group.name
  vpc_security_group_ids = [aws_security_group.rds_access.id]

  tags = {
    Name = "${var.PRE}rds"
    Owner = var.OWNER
  }
}

output "rds_address" {
  value = aws_db_instance.rds.address
}

# Load Balancer + stuff

resource "aws_lb" "alb" {
  name               = "${var.PRE}alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_access.id]
  subnets            = [aws_subnet.sn_pub_az1.id, aws_subnet.sn_pub_az2.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.PRE}alb"
    Owner = var.OWNER
  }
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

resource "aws_lb_target_group" "db_app_tg" {
  name        = "${var.PRE}tg-db-app"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main_vpc.id
}

output "db_app_tg_arn" {
  value = aws_lb_target_group.db_app_tg.arn
}

resource "aws_lb_target_group" "s3_app_tg" {
  name        = "${var.PRE}tg-s3-app"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main_vpc.id
}

output "s3_app_tg_arn" {
  value = aws_lb_target_group.s3_app_tg.arn
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.db_app_tg.arn
  }
}

resource "aws_lb_listener_rule" "db_app_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.db_app_tg.arn
  }

  condition {
    path_pattern {
      values = ["/crud/*"]
    }
  }
}

resource "aws_lb_listener_rule" "s3_app_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3_app_tg.arn
  }

  condition {
    path_pattern {
      values = ["/s3*"]
    }
  }
}


# ECR

resource "aws_ecr_repository" "db_app_repo" {
  name = "${var.PRE}db-app-repo"
  tags = {
    Name = "${var.PRE}db-app-repo"
    Owner = var.OWNER
  }
}

output "db_app_repo_url" {
  value = aws_ecr_repository.db_app_repo.repository_url
}

resource "aws_ecr_repository" "s3_app_repo" {
  name = "${var.PRE}s3-app-repo"
  tags = {
    Name = "${var.PRE}s3-app-repo"
    Owner = var.OWNER
  }
}

output "s3_app_repo_url" {
  value = aws_ecr_repository.s3_app_repo.repository_url
}

# ECS

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.PRE}ecs-cluster"
  tags = {
    Name = "${var.PRE}ecs-cluster"
    Owner = var.OWNER
  }
}

output "cluster_id" {
  value = aws_ecs_cluster.ecs_cluster.id
}

resource "aws_iam_role" "ecs_task_exec_role" {
  name               = "${var.PRE}ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = {
    Name = "${var.PRE}ecs-task-exec-role"
    Owner = var.OWNER
  }
}

output "ecs_task_exec_role_arn" {
  value = aws_iam_role.ecs_task_exec_role.arn
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecsECRAccess_policy" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}


resource "aws_service_discovery_private_dns_namespace" "namespace" {
    name        = "${var.PRE}.local"
    description = "prv dns namespace for ups007"
    vpc         = aws_vpc.main_vpc.id
}

output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.namespace.id
}
