# Master SG
resource "aws_security_group" "k8s_master_sg" {
  name        = "k8s-master-sg"
  description = "Kubernetes Master SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"] # Worker CIDR
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Worker SG
resource "aws_security_group" "k8s_worker_sg" {
  name        = "k8s-worker-sg"
  description = "Kubernetes Worker SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Master CIDR
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # External access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output SG IDs
output "master_sg_id" {
  value = aws_security_group.k8s_master_sg.id
}

output "worker_sg_id" {
  value = aws_security_group.k8s_worker_sg.id
}
