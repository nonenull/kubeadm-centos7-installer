#!/bin/bash

ntp_server=ntp1.aliyun.com
API_SERVER_PORT=${API_SERVER_PORT-6443}

if [ ${#NODE_HOSTNAME} -eq 0 ] || [ ${#API_SERVER_IP} -eq 0 ] || [ ${#API_SERVER_DNS_NAME} -eq 0 ]; then
  echo -e "\033[31;1m请确保您已经设置了环境变量 NODE_HOSTNAME 和 API_SERVER_IP 和 API_SERVER_HOST \033[0m"
  echo 当前 NODE_HOSTNAME=${NODE_HOSTNAME}
  echo 当前 API_SERVER_IP=${API_SERVER_IP}
  echo 当前 API_SERVER_DNS_NAME=${API_SERVER_DNS_NAME}
  exit 1
fi

# insert hosts info to /etc/hosts
hostnamectl set-hostname ${NODE_HOSTNAME}
echo "127.0.0.1  ${NODE_HOSTNAME}" >> /etc/hosts
echo "${API_SERVER_IP}  ${API_SERVER_DNS_NAME}" >> /etc/hosts

# disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a

# disable selinx
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# update sysctl iptables parameter
cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
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
                nfs-utils \
                containerd.io \
                docker-ce \
                docker-ce-cli \
                kubelet \
                kubeadm \
                kubectl

# ntp update time
systemctl enable ntpd
systemctl start ntpd
#ntpdate ${ntp_server}
#hwclock -w
#echo "*/5 * * * * ntpdate ${ntp_server}" | crontab -

# set docker config
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
    "registry-mirrors": ["https://qqnn8qm9.mirror.aliyuncs.com"],
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOF

systemctl enable docker
systemctl restart docker
sleep 3
systemctl status docker -l

cat <<EOF > /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd
EOF
systemctl enable kubelet
