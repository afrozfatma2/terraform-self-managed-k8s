#!/bin/bash
set -xe

# ------------------------------
# CONFIGURATION - EDIT THIS
# ------------------------------
# Get join command from SSM or set manually
# Example: JOIN_CMD="kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>"
JOIN_CMD=$(aws ssm get-parameter --name "k8sJoinCommand" --query "Parameter.Value" --output text --region ap-south-1)

# ------------------------------
# UPDATE SYSTEM
# ------------------------------
sudo yum update -y

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# ------------------------------
# CONTAINERD SETUP
# ------------------------------
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

sudo yum install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl enable --now containerd

# ------------------------------
# KUBERNETES SETUP
# ------------------------------
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repomd.xml.key
EOF

sudo yum install -y kubelet kubeadm --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# ------------------------------
# JOIN CLUSTER
# ------------------------------
# Make sure kubelet is running before join
sudo systemctl restart kubelet

# Join the cluster
sudo $JOIN_CMD
