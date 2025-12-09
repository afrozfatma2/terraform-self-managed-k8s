#!/bin/bash
set -e

# Update
yum update -y

# Install Docker & AWS CLI
amazon-linux-extras install docker -y
yum install -y awscli iptables-services
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
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet

# Docker cgroup fix
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
systemctl restart docker
systemctl restart kubelet

# Init master
kubeadm init --pod-network-cidr=192.168.0.0/16 | tee /root/kubeinit.txt

# Configure kubectl for ec2-user
mkdir -p /home/ec2-user/.kube
cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config

# Install Calico Network
sudo -u ec2-user kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Wait a bit for API server
sleep 30

# Generate join command & store in SSM
JOIN_CMD=$(kubeadm token create --print-join-command)
aws ssm put-parameter \
  --name "k8sJoinCommand" \
  --value "$JOIN_CMD" \
  --type String \
  --overwrite \
  --region ap-south-1
