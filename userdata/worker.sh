#!/bin/bash


#aws cli and docker
#swap disable
#k8s components
#join cmd from SSM 
#run join cmd

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
systemctl start kubelet

# -fetch join cmd from SSM (fetching token)
JOIN_CMD=$(aws ssm get-parameter \
  --name "k8sJoinCommand" \
  --region us-east-1 \
  --query "Parameter.Value" \
  --output text)

# -run join cmd
eval $JOIN_CMD
