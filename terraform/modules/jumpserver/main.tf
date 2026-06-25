# ── Key Pair ─────────────────────────────────────────────────────────────────
# If you pass an existing key name, we skip creation.
# If you pass a public key string, we create the key pair.

# ── Latest Ubuntu 22.04 AMI ──────────────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM Role for Jump Server ─────────────────────────────────────────────────
# Lets the jump server run AWS CLI commands without hardcoded credentials
resource "aws_iam_role" "jumpserver" {
  name = "${var.project_name}-jumpserver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_full" {
  role       = aws_iam_role.jumpserver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.jumpserver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Inline policy: describe EKS + update-kubeconfig + ECR login
resource "aws_iam_role_policy" "jumpserver_eks" {
  name = "${var.project_name}-jumpserver-eks-policy"
  role = aws_iam_role.jumpserver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRLogin"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3SNSForApp"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jumpserver" {
  name = "${var.project_name}-jumpserver-profile"
  role = aws_iam_role.jumpserver.name
  tags = var.tags
}

# ── Jump Server EC2 ───────────────────────────────────────────────────────────
resource "aws_instance" "jumpserver" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.existing_key_name 
  iam_instance_profile        = aws_iam_instance_profile.jumpserver.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 25
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # Bootstrap: installs kubectl, AWS CLI, Docker, Helm, and configures kubeconfig
 

  tags = merge(var.tags, {
    Name = "${var.project_name}-jumpserver"
    Role = "jumpserver"
  })
}

# ── Elastic IP (optional, keeps IP stable across stop/start) ─────────────────

resource "aws_eip" "jumpserver" {
  count      = var.enable_eip ? 1 : 0
  instance   = aws_instance.jumpserver.id
  depends_on = [aws_instance.jumpserver]

  tags = merge(var.tags, { Name = "${var.project_name}-jumpserver-eip" })
}