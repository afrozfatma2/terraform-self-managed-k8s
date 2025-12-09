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
# INSTALL DOCKER
# ------------------------------
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker

# Configure Docker to use systemd cgroup driver
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker

# ------------------------------
# KUBERNETES PREREQUISITES
# ------------------------------
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

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
# GET JOIN COMMAND FROM AWS SSM
# ------------------------------
JOIN_CMD=$(aws ssm get-parameter \
  --name "k8sJoinCommand" \
  --region ap-south-1 \
  --query "Parameter.Value" \
  --output text)

# ------------------------------
# JOIN KUBERNETES CLUSTER
# ------------------------------
sudo $JOIN_CMD --cri-socket /var/run/dockershim.sock

# ------------------------------
# START KUBELET
# ------------------------------
sudo systemctl restart kubelet
