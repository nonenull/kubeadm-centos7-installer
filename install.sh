#!/bin/bash
##########
#   this bash file exec in the master machine.
#   before use this bash, must exec cmd like bellow:
#
#       ssh-keygen -t rsa
#       ssh-copy-id root@{{every node}}
#
##########
yum install -y epel-release
yum install -y jq
LOG_PATH="./logs"
INIT_FINISHED_TAG=">> init finished"
JOIN_FINISHED_TAG=">> join finished"
MASTER_JOIN_CMD=""
NODE_JOIN_CMD=""

CONFIG_FILE_CONTENT=$(cat config.json)
master_len=$(echo ${CONFIG_FILE_CONTENT} | jq '.master | length')
node_len=$(echo ${CONFIG_FILE_CONTENT} | jq '.node | length')

MAIN_MASTER_IP=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".master[0].ip")
API_SERVER_IP=${MAIN_MASTER_IP}
API_SERVER_DNS_NAME=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".api_server_lb.dns_name")
API_SERVER_PORT=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".api_server_lb.port")

mkdir -p ${LOG_PATH}

function generate_log_path(){
    role=$1
    hostname=$2
    echo "${LOG_PATH}/kube_${role}_${hostname}.log"
}

function _remote_init_other_node(){
    hostname=$1
    ip=$2
    scp init.sh root@${ip}:/tmp/
    ssh root@${ip} bash << EOF
        export NODE_HOSTNAME=${hostname}
        export API_SERVER_DNS_NAME=${API_SERVER_DNS_NAME}
        export API_SERVER_IP=${MAIN_MASTER_IP}
        export API_SERVER_PORT=${API_SERVER_PORT}
        bash /tmp/init.sh
        echo "${INIT_FINISHED_TAG}"
EOF
}

function remote_init_other_node(){
    for((i=0;i<${node_len};i++))
    do
        node_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].hostname")
        node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
        node_log=$(generate_log_path "node" ${node_hostname})
        echo
        echo "[async] node: ready to exec remote script:  ${node_ip}"
        echo "if you want to see remote log, please see:  ${node_log}"
        _remote_init_other_node "${node_hostname}" "${node_ip}" > ${node_log} 2>&1 &
        echo
    done

    for((i=1;i<${master_len};i++))
    do
        master_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".master[${i}].hostname")
        master_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".master[${i}].ip")
        master_log=$(generate_log_path "master" ${master_hostname})
        echo
        echo "[async] master: ready to exec remote script:  ${master_ip}"
        echo "if you want to see remote log, please see:  ${master_log}"
        _remote_init_other_node "${master_hostname}" "${master_ip}" > ${master_log} 2>&1 &
        echo
    done
}

function _join_node_to_cluster(){
    ip=$1
    cmd_type=$2
    if [[ ${cmd_type} == "master" ]];then
        cmd=$(cat <<EOF
            ${MASTER_JOIN_CMD}
            mkdir -p $HOME/.kube
            cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
            chown $(id -u):$(id -g) $HOME/.kube/config
EOF
)
    else
        cmd=${NODE_JOIN_CMD}
    fi
    ssh root@${ip} bash <<EOF
        ${cmd}
        echo "${JOIN_FINISHED_TAG}"
EOF
}

function join_node_to_cluster(){
    undone_ip=""
    echo -e "\n\n\n\n"

    for((i=0;i<${node_len};i++))
    do
        node_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].hostname")
        node_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".node[${i}].ip")
        node_log=$(generate_log_path "node" ${node_hostname})

        _=$(tail -n 1 ${node_log} | grep "${INIT_FINISHED_TAG}")
        if [[ $? -eq 0 ]];then
            _join_node_to_cluster "${node_ip}" >> ${node_log} 2>&1 &
        else
            echo "${node_log} undone..."
            undone_ip="${undone_ip} ${node_ip}"
        fi
    done

    for((i=1;i<${master_len};i++))
    do
        master_hostname=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".master[${i}].hostname")
        master_ip=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".master[${i}].ip")
        master_log=$(generate_log_path "master" ${master_hostname})

        _=$(tail -n 1 ${master_log} | grep "${INIT_FINISHED_TAG}")
        if [[ $? -eq 0 ]];then
            _join_node_to_cluster "${master_ip}" "master" >> ${master_log} 2>&1 &
        else
            echo "${master_log} undone..."
            undone_ip="${undone_ip} ${master_ip}"
        fi
    done
    if [[ ! ${undone_ip} == "" ]];then
        join_node_to_cluster
    fi
}

function install_main_master(){
    export NODE_HOSTNAME=$(echo ${CONFIG_FILE_CONTENT} | jq -r ".master[0].hostname")
    export API_SERVER_IP=${API_SERVER_IP}
    export API_SERVER_DNS_NAME=${API_SERVER_DNS_NAME}
    export API_SERVER_PORT=${API_SERVER_PORT}
    bash init.sh

    kube_init_log="${LOG_PATH}/kubeadm_init.log"
    kubeadm init \
        --image-repository registry.aliyuncs.com/google_containers \
        --control-plane-endpoint ${API_SERVER_DNS_NAME}:${API_SERVER_PORT} \
        --apiserver-advertise-address=0.0.0.0 \
        --service-cidr=10.1.0.0/16 \
        --pod-network-cidr=10.244.0.0/16 \
        --upload-certs \
        | tee ${kube_init_log}

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    MASTER_JOIN_CMD=$(grep -B 2 "control-plane --certificate-key" ${kube_init_log})
    NODE_JOIN_CMD=$(kubeadm token create --print-join-command 2>/dev/null)

    kubectl apply -f https://docs.projectcalico.org/manifests/calico-typha.yaml
}

function main(){
    remote_init_other_node
    install_main_master
    wait
    join_node_to_cluster
    wait
    watch 'kubectl get nodes; kubectl get pods -n kube-system'
}

if [ "$1" ];then
    $1
else
    main
fi