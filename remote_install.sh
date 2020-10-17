#!/bin/bash
##########
#   this bash file exec in the master machine.
#   before use this bash, must exec cmd like bellow:
#
#       ssh-keygen -t rsa
#       ssh-copy-id root@{{every node}}
#
##########
yum install -y jq

CONFIG_FILE_CONTENT=$(cat config.json)
HOSTS_CONTENT=""

function add_host_record(){
    ip=$1
    host=$2
    HOSTS_CONTENT="${HOSTS_CONTENT}\n${ip}  ${host}"
}

function exec_remote_script(){
    ip=$1
    scp init.sh root@${ip}:/tmp/
    ssh root@${node_ip} bash <<EOF
    bash /tmp/init.sh "${HOSTS_CONTENT}"
EOF
}

function pre_exec_remote_script(){
    ip=$1
    log_path="kube_install_${ip}.log"
    echo "[async] ready to exec remote script:  ${ip}"
    echo "if you want to see remote log, please see:  ${log_path}"
    exec_remote_script ${ip} > ${log_path} 2>&1 &
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


# install master
echo "ready to exec master script:  ${master_ip}"
log_path="kube_install_${master_ip}.log"
echo "if you want to see log, please see:  ${log_path}"
bash init.sh "${HOSTS_CONTENT}"

kubeadm init \
    --apiserver-advertise-address=${master_ip} \
    --image-repository registry.aliyuncs.com/google_containers \
    --service-cidr=10.1.0.0/16 \
    --pod-network-cidr=10.244.0.0/16

# install node
#for((i=0;i<${node_len};i++))
#do
#    node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
#    pre_exec_remote_script ${node_ip}
#done
