## a simple way to install kubernetes cluster



```
git clone https://github.com/nonenull/kubeadm-centos7-installer.git

# Follow the example to set the master and node.
cp config.json.template config.json
bash install.sh
```

# how to set config.json
```
{
  "kubernetes_version": "1.19.3",           # set the kubenetes version, currently not working
  "api_server_lb": {                        # currently not working
    "dns_name": "apiserver.k8s.xxxx.com",   # api server domain, will insert to /etc/hosts
    "ip": "192.168.87.151",                 # api server ip, will insert to /etc/hosts
    "port": 6443                            # api server port
  },
  "master": [                               # set master node
    {
      "hostname": "master1.k8s.xxxx.com",
      "ip": "192.168.87.147"
    }
  ],
  "node": [                                 # set worker node
    {
      "hostname": "node1.k8s.xxxx.com",
      "ip": "192.168.87.149"
    }
  ]
}
```