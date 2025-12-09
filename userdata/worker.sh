#!/bin/bash
set -e

echo "Updating system..."
sudo yum update -y

echo "Installing Docker..."
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "Adding Kubernetes repository..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo yum install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet
sudo systemctl start kubelet

echo "Initializing Kubernetes master..."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 | tee kubeadm-init.log

echo "Setting up kubeconfig for user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Installing Calico network plugin..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Extract kubeadm join command
JOIN_COMMAND=$(grep "kubeadm join" kubeadm-init.log -A 2 | tr -d '\n')
echo "===================================================="
echo "Use the following command on worker nodes to join the cluster:"
echo "$JOIN_COMMAND"
echo "===================================================="
