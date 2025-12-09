#!/bin/bash

#aws cli and docker
#swap disable
#k8s components
#init master node
#kubectl and ec2-user 
#Calico Network Plugin
#store and overwrite token

yum update -y

#-Installing aws cli and docker
amazon-linux-extras install docker -y
yum install -y awscli

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# -sawp disable (commenting out in /etc/fstab)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# -installing k8s components
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

yum install -y kubelet kubeadm kubectl
systemctl enable kubelet

# -init master node
kubeadm init --pod-network-cidr=192.168.0.0/16 | tee /root/kubeinit.txt

# -config kubectl and ec2-user 
mkdir -p /home/ec2-user/.kube
cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config

# -install Calico Network Plugin
sudo -u ec2-user kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# -generate join cmd
JOIN_CMD=$(kubeadm token create --print-join-command)

# -store and overwrite token in parameter store (ssm)
aws ssm put-parameter \
  --name "k8sJoinCommand" \
  --value "$JOIN_CMD" \
  --type String \
  --overwrite \
  --region ap-south-1
