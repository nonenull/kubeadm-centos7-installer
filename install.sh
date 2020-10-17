#!/bin/bash

##########
#   this bash file exec in the master machine.
#   before use this bash, must exec cmd like bellow:
#
#       yum install -y jq  or  apt install -y jq
#       ssh-keygen -t rsa
#       ssh-copy-id root@{{every node}}
#
##########

CONFIG_FILE_CONTENT=$(cat config.json)
HOSTS_CONTENT=""

function add_host_record(){
    ip=$1
    host=$2
    HOSTS_CONTENT="${HOSTS_CONTENT}\n${ip}  ${host}"
}

master_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r .master.hostname)
master_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r .master.ip)
hostnamectl set-hostname ${master_hostname}
add_host_record ${master_ip} ${master_hostname}

node_len=$(echo ${CONFIG_FILE_CONTENT} | jq '.node | length')
for((i=0;i<${node_len};i++))
do
    node_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].hostname")
    node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
    add_host_record ${node_ip} ${node_hostname}
done

#./init.sh "${HOSTS_CONTENT}" 2>&1>./${master_ip}.log &

for((i=0;i<${node_len};i++))
do
    node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
    scp init.sh root@${node_ip}:/tmp/
    ssh root@${node_ip} bash <<EOF
    bash /tmp/init.sh "${HOSTS_CONTENT}" 2>&1>./tmp/${node_ip}.log &
EOF
done

#kubeadm init \
#    --apiserver-advertise-address=${master_ip} \
#    --image-repository registry.aliyuncs.com/google_containers \
#    --service-cidr=10.1.0.0/16 \
#    --pod-network-cidr=10.244.0.0/16