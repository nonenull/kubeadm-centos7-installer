## a simple way to install kubernetes cluster

```
git clone https://github.com/nonenull/kubeadm-centos7-installer.git

# Follow the example to set the master and node.
cp config.json.template config.json
bash install.sh
```

## test system info
```
# cat /etc/redhat-release
    CentOS Linux release 7.8.2003 (Core)

# cat /etc/os-release
    NAME="CentOS Linux"
    VERSION="7 (Core)"
    ID="centos"
    ID_LIKE="rhel fedora"
    VERSION_ID="7"
    PRETTY_NAME="CentOS Linux 7 (Core)"
    ANSI_COLOR="0;31"
    CPE_NAME="cpe:/o:centos:centos:7"
    HOME_URL="https://www.centos.org/"
    BUG_REPORT_URL="https://bugs.centos.org/"

    CENTOS_MANTISBT_PROJECT="CentOS-7"
    CENTOS_MANTISBT_PROJECT_VERSION="7"
    REDHAT_SUPPORT_PRODUCT="centos"
    REDHAT_SUPPORT_PRODUCT_VERSION="7"

# cat /proc/version
    Linux version 3.10.0-1127.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-39) (GCC) ) #1 SMP Tue Mar 31 23:36:51 UTC 2020

```

## config.json comment
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