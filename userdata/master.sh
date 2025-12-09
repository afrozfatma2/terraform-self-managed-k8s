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

# Make sure Docker uses systemd cgroup driver
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
# INITIALIZE K8S MASTER
# ------------------------------
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
  --cri-socket /var/run/dockershim.sock \
  | tee /root/kubeinit.txt

# ------------------------------
# SETUP KUBECTL FOR CURRENT USER
# ------------------------------
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
echo "export KUBECONFIG=$HOME/.kube/config" >> ~/.bashrc

# ------------------------------
# INSTALL CALICO NETWORK
# ------------------------------
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# ------------------------------
# SAVE JOIN COMMAND IN AWS SSM PARAMETER STORE
# ------#!/bin/bash
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
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

echo "Setting up kubeconfig for user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Installing Calico network plugin..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Master setup complete!"
echo "Run the kubeadm join command displayed above on worker nodes."
------------------------
JOIN_CMD=$(kubeadm token create --print-join-command)
aws ssm put-parameter \
  --name "k8sJoinCommand" \
  --value "$JOIN_CMD" \
  --overwrite \
  --type String \
  --region ap-south-1
