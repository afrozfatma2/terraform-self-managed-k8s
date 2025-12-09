#!/bin/bash
set -xe

# ------------------------------
# UPDATE SYSTEM
# ------------------------------
sudo yum update -y

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# ------------------------------
# INSTALL CONTAINERD
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

containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl enable --now containerd


# ------------------------------
# INSTALL KUBERNETES
# ------------------------------
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet


# ------------------------------
# FETCH JOIN COMMAND FROM SSM
# ------------------------------
JOIN_CMD=$(aws ssm get-parameter \
  --name "k8sJoinCommand" \
  --region ap-south-1 \
  --query "Parameter.Value" \
  --output text)

# ------------------------------
# JOIN THE CLUSTER
# ------------------------------
sudo $JOIN_CMD
