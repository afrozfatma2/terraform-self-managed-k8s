#!/bin/bash
set -e

# ---------------------------
# Update
# ---------------------------
dnf update -y

# Install base packages
dnf install -y tar wget curl git awscli

# Disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab

# Enable kernel modules
cat <<EOF | tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Install CRI-O
OS_VERSION="v1.30"
CRIO_VERSION="1.30"

curl -L -o /etc/yum.repos.d/libcontainers-stable.repo \
 https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_Stream_9/devel:kubic:libcontainers:stable.repo

curl -L -o /etc/yum.repos.d/crio.repo \
 https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/CentOS_Stream_9/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo

dnf install -y cri-o

systemctl enable crio
systemctl start crio

# Kubernetes repo
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

dnf install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl start kubelet

# ---------------------------
# Download the join command from SSM
# ---------------------------
JOIN_CMD=$(aws ssm get-parameter \
  --name "k8sJoinCommand" \
  --region ap-south-1 \
  --query Parameter.Value \
  --output text)

# ---------------------------
# Join the cluster
# ---------------------------
bash -c "$JOIN_CMD"

echo "Worker node joined successfully."
