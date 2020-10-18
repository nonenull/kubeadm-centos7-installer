#!/bin/bash
##########
#   this bash file exec in the master machine.
#   before use this bash, must exec cmd like bellow:
#
#       ssh-keygen -t rsa
#       ssh-copy-id root@{{every node}}
#
##########

FINISHED_TAG=">> install finished"
HOSTS_CONTENT=""
JOIN_CMD=""
CONFIG_FILE_CONTENT=$(cat config.json)
node_len=$(echo ${CONFIG_FILE_CONTENT} | jq '.node | length')

yum install -y jq

function add_host_record(){
    ip=$1
    host=$2
    HOSTS_CONTENT="${HOSTS_CONTENT}\n${ip}  ${host}"
}

# install node
function exec_remote_script(){
    ip=$1
    scp node.sh root@${ip}:/tmp/
    ssh root@${ip} bash <<EOF
    bash /tmp/node.sh "${HOSTS_CONTENT}"
    ${JOIN_CMD}
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    echo ${FINISHED_TAG}
EOF
}

function pre_exec_remote_script(){
    ip=$1
    log_path="kube_node_${ip}.log"
    echo "[async] ready to exec remote script:  ${ip}"
    echo "if you want to see remote log, please see:  ${log_path}"
    exec_remote_script ${ip} > ${log_path} 2>&1 &
}

function install_node(){
    for((i=0;i<${node_len};i++))
    do
        node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
        pre_exec_remote_script ${node_ip}
    done
}

function set_hostname(){
    master_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r .master.hostname)
    master_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r .master.ip)
    hostnamectl set-hostname ${master_hostname}
    add_host_record ${master_ip} ${master_hostname}

    # save nodes hostname
    for((i=0;i<${node_len};i++))
    do
        node_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].hostname")
        node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
        add_host_record ${node_ip} ${node_hostname}
    done
}

function install_master(){
    # install master
    log_path="kube_install_${master_hostname}.log"
    echo "ready to exec master script:  ${master_ip}"
    echo "if you want to see log, please see:  ${log_path}"
    bash master.sh "${HOSTS_CONTENT}" > ${log_path} 2>&1

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    JOIN_CMD=$(kubeadm token create --print-join-command 2>/dev/null)
}

# check node install result
function check_node_progress(){
    _node_logs=$1
    for node_log in ${_node_logs}
    do
        _=$(tail -1 ${node_log} |grep "${FINISHED_TAG}")
        if [[ $? -eq 0 ]];then
            echo "[${node_log}] install finished"
            _node_logs=$(echo ${_node_logs} | sed -e "s/${node_log}//")
        else
            echo "[${node_log}] install unfinished, wait to check again"
            sleep 1
            check_node_progress ${_node_logs}
        fi
    done
}

function main(){
    set_hostname
    install_master

    install_node

    node_logs=`ls kube_node_*.log`
    check_node_progress "${node_logs}"
}

main