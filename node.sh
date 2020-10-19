#!/bin/bash

ntp_server=ntp1.aliyun.com

# insert hosts info to /etc/hosts
if [[ $# -eq 1 ]]; then
    echo -e $1 >> /etc/hosts
fi

# disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a

# disable selinx
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# update sysctl iptables parameter
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# firewall allow k8s ports
systemctl disable firewalld
systemctl stop firewalld

# set package repo
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# install software
yum remove -y docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-engine

yum makecache -y
yum install -y --nogpgcheck --disableexcludes=kubernetes \
                yum-utils \
                device-mapper-persistent-data \
                lvm2 \
                containerd.io \
                docker-ce \
                docker-ce-cli \
                kubelet \
                kubeadm \
                kubectl

# ntp update time
ntpdate ${ntp_server}
hwclock -w
echo "*/5 * * * * ntpdate ${ntp_server}" | crontab -

# set docker config
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
    "registry-mirrors": ["https://qqnn8qm9.mirror.aliyuncs.com"],
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    }
}
EOF

systemctl enable docker
systemctl restart docker
systemctl status docker -l

cat <<EOF > /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --feature-gates SupportPodPidsLimit=false --feature-gates SupportNodePidsLimit=false
EOF
systemctl enable kubelet