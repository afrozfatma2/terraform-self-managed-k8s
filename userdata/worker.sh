#!/bin/bash
set -e

dnf update -y

# Install Docker
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kubernetes repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
EOF

# Install kubeadm, kubelet, kubectl
dnf install -y kubelet kubeadm kubectl
systemctl enable kubelet

# Fetch join command from SSM
JOIN_CMD=$(aws ssm get-parameter --name "k8sJoinCommand" --query "Parameter.Value" --output text --region ap-south-1)

# Join the cluster
$JOIN_CMD
