# VPC Core Resource
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name       = "${var.environment}-banking-vpc"
    Compliance = "PCI-DSS-4.0"
  }
}

# 3-Tier Subnets
resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 0)
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-web-tier"
    Tier = "Web"
  }
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 1)
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-app-tier"
    Tier = "App"
  }
}

resource "aws_subnet" "data" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 2)
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.environment}-data-tier"
    Tier = "Data"
  }
}

# Internet Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name       = "${var.environment}-igw"
    Compliance = "PCI-DSS-4.0"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "web_assoc" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public_rt.id
}

# Zero-Trust Security Group Chaining
#trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "web_sg" {
  name        = "${var.environment}-web-sg"
  description = "Allow HTTPS inbound from corporate network and egress to VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS inbound from internal corporate CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow egress to application tier within VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name       = "${var.environment}-web-sg"
    Compliance = "PCI-DSS-4.0"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-app-sg"
  description = "Allow inbound API traffic exclusively chained from Web SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow port 8080 chained strictly from Web SG"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    description = "Allow database traffic egress to Data SG within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name       = "${var.environment}-app-sg"
    Compliance = "PCI-DSS-4.0"
  }
}

resource "aws_security_group" "data_sg" {
  name        = "${var.environment}-data-sg"
  description = "Allow PostgreSQL traffic exclusively chained from App SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow PostgreSQL port 5432 chained strictly from App SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    description = "Restricted egress within internal VPC CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name       = "${var.environment}-data-sg"
    Compliance = "PCI-DSS-4.0"
  }
}

# Customer Managed Key (CMK) Governance
resource "aws_kms_key" "banking_key" {
  description             = "Customer Managed Key (CMK) for ${var.environment} financial records"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name       = "${var.environment}-banking-cmk"
    Compliance = "PCI-DSS-4.0"
  }
}

resource "aws_kms_alias" "banking_key_alias" {
  name          = "alias/${var.environment}-pgh-banking-key"
  target_key_id = aws_kms_key.banking_key.key_id
}

# SEC Rule 17a-4 Storage Bucket
resource "aws_s3_bucket" "audit_logs" {
  bucket              = "${var.environment}-pgh-banking-audit-logs"
  object_lock_enabled = true

  tags = {
    Name       = "${var.environment}-audit-logs"
    Compliance = "SEC-17a-4"
  }
}

resource "aws_s3_bucket_versioning" "audit_logs_versioning" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs_encryption" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.banking_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "audit_logs_lock" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 30
    }
  }

  depends_on = [aws_s3_bucket_versioning.audit_logs_versioning]
}

resource "aws_s3_bucket_public_access_block" "audit_logs_public_block" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VPC Flow Logs & Observability
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/${var.environment}-bank-logs"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.banking_key.arn

  tags = {
    Name       = "${var.environment}-flow-logs"
    Compliance = "PCI-DSS-4.0"
  }
}

resource "aws_iam_role" "flow" {
  name = "${var.environment}-vpc-flow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_policy" {
  name = "${var.environment}-vpc-flow-policy"
  role = aws_iam_role.flow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.flow.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow.arn
  log_destination = aws_cloudwatch_log_group.flow.arn
}
