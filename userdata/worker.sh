#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 '<kubeadm join command from master>'"
    exit 1
fi

JOIN_CMD="$1"

echo "=== Updating system ==="
sudo dnf update -y

# Function to check and install a command if missing
install_if_missing() {
    CMD=$1
    PKG=$2
    if ! command -v $CMD &> /dev/null; then
        echo "Installing $CMD..."
        sudo dnf install -y $PKG
    else
        echo "$CMD is already installed"
    fi
}

echo "=== Installing Docker ==="
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
install_if_missing docker docker-ce

sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker --no-pager || { echo "Docker failed to start"; exit 1; }

echo "=== Disabling swap ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "=== Adding Kubernetes repository ==="
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

echo "=== Installing kubeadm, kubelet, kubectl ==="
install_if_missing kubeadm kubeadm
install_if_missing kubelet kubelet
install_if_missing kubectl kubectl

sudo systemctl enable kubelet
sudo systemctl start kubelet
sudo systemctl status kubelet --no-pager || { echo "kubelet failed to start"; exit 1; }

echo "=== Joining the Kubernetes cluster ==="
sudo $JOIN_CMD

echo "Worker node setup complete!"
