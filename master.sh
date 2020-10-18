#!/bin/bash

bash node.sh $1
kubeadm init \
    --image-repository registry.aliyuncs.com/google_containers \
    --service-cidr=10.1.0.0/16 \
    --pod-network-cidr=10.244.0.0/16