#!/bin/bash
set -e

# ---------------------------
# Update system
# ---------------------------
dnf update -y

# ---------------------------
# Install required packages
# ---------------------------
dnf install -y tar wget curl git

# ---------------------------
# Disable swap (required for Kubernetes)
# ---------------------------
swapoff -a
sed -i '/swap/d' /etc/fstab

# ---------------------------
# Enable container runtime (CRI-O)
# ---------------------------
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

# Install CRI-O repo
OS_VERSION="v1.30"
CRIO_VERSION="1.30"

curl -L -o /etc/yum.repos.d/libcontainers-stable.repo \
 https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_Stream_9/devel:kubic:libcontainers:stable.repo

curl -L -o /etc/yum.repos.d/crio.repo \
 https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/CentOS_Stream_9/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.repo

dnf install -y cri-o

systemctl enable crio
systemctl start crio

# ---------------------------
# Kubernetes repo
# ---------------------------
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

# Install Kubernetes programs
dnf install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl start kubelet

# ---------------------------
# Initialize Kubernetes master
# ---------------------------
kubeadm init --pod-network-cidr=192.168.0.0/16 | tee /root/kubeinit.txt

# ---------------------------
# Configure kubectl for ec2-user
# ---------------------------
mkdir -p /home/ec2-user/.kube
cp /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config

# ---------------------------
# Install Calico network plugin
# ---------------------------
sudo -u ec2-user kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# ---------------------------
# Create worker join command & store in SSM
# ---------------------------
JOIN_CMD=$(kubeadm token create --print-join-command)

dnf install -y awscli

aws ssm put-parameter \
  --name "k8sJoinCommand" \
  --value "$JOIN_CMD" \
  --type String \
  --overwrite \
  --region ap-south-1

echo "Master setup complete."
