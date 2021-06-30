#!/bin/bash

# wireguard 
# assumes all ubuntu 20.04

# env
set -e
password=Pa22word
zone=nyc3
size=s-1vcpu-2gb-amd   
key=30:98:4f:c5:47:c2:88:28:fe:3c:23:cd:52:49:51:01
domain=dockr.life

image=ubuntu-20-04-x64

######  NO MOAR EDITS #######
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)
BLUE=$(tput setaf 4)

export PDSH_RCMD_TYPE=ssh

############################# setup ###############################
function setup () {
  echo -n " building vms "
  # setup VMs
  doctl compute droplet create nginx client --region $zone --image $image --size $size --ssh-keys $key --wait > /dev/null 2>&1

  export server_ip=$(doctl compute droplet list --no-header | grep nginx | awk '{print $3}')
  export client_ip=$(doctl compute droplet list --no-header | grep client | awk '{print $3}')

  doctl compute domain records create $domain --record-type A --record-name nginx --record-ttl 300 --record-data $server_ip > /dev/null 2>&1
  doctl compute domain records create $domain --record-type A --record-name client --record-ttl 300 --record-data $client_ip > /dev/null 2>&1
  doctl compute domain records create $domain --record-type CNAME --record-name "*" --record-ttl 150 --record-data nginx.$domain. > /dev/null 2>&1

  echo "$GREEN" "ok" "$NORMAL"

  echo -n " installing docker/updates and rebooting "

  # wait for ssh
  until [ $(ssh -o ConnectTimeout=1 root@$server_ip 'exit' 2>&1 | grep 'timed out\|refused' | wc -l) = 0 ]; do echo -n "." ;sleep 5; done
  until [ $(ssh -o ConnectTimeout=1 root@$client_ip 'exit' 2>&1 | grep 'timed out\|refused' | wc -l) = 0 ]; do echo -n "." ;sleep 5; done

  # setup up dockers
  pdsh -l root -w "$server_ip","$client_ip" 'curl https://get.docker.com/ | bash && export DEBIAN_FRONTEND=noninteractive; apt update && apt upgrade -y && apt autoremove -y; curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose; chmod +x /usr/local/bin/docker-compose; cat << EOF >> /etc/sysctl.conf
# SWAP settings
vm.swappiness=0
vm.overcommit_memory=1

# Have a larger connection range available
net.ipv4.ip_local_port_range=1024 65000

# Increase max connection
net.core.somaxconn = 10000

# Reuse closed sockets faster
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# The maximum number of "backlogged sockets".  Default is 128.
net.core.somaxconn=4096
net.core.netdev_max_backlog=4096

# 16MB per socket - which sounds like a lot,
# but will virtually never consume that much.
net.core.rmem_max=16777216
net.core.wmem_max=16777216

# Various network tunables
net.ipv4.tcp_max_syn_backlog=20480
net.ipv4.tcp_max_tw_buckets=400000
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_wmem=4096 65536 16777216

# ARP cache settings for a highly loaded docker swarm
net.ipv4.neigh.default.gc_thresh1=8096
net.ipv4.neigh.default.gc_thresh2=12288
net.ipv4.neigh.default.gc_thresh3=16384

# ip_forward and tcp keepalive for iptables
net.ipv4.tcp_keepalive_time=600
net.ipv4.ip_forward=1

# monitor file system events
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
EOF
useradd -u 1000 -G docker wireguard; reboot' > /dev/null 2>&1

  # wait for reboot
  until [ $(ssh -o ConnectTimeout=1 root@$server_ip 'exit' 2>&1 | grep 'timed out\|refused' | wc -l) = 0 ]; do echo -n "." ;sleep 5; done
  until [ $(ssh -o ConnectTimeout=1 root@$client_ip 'exit' 2>&1 | grep 'timed out\|refused' | wc -l) = 0 ]; do echo -n "." ;sleep 5; done

  echo "$GREEN" "ok" "$NORMAL"

  echo -n " deploying nginx, keycloak, vault, and wiregaurd "
  rsync -avP docker-compose.yaml root@nginx.dockr.life:/opt

  # docker compose all the things
  ssh root@nginx.dockr.life 'cd /opt; mkdir /opt/{nginx,wireguard,keycloak}; echo "wireguard for the win..." > /opt/nginx/index.html; docker-compose up -d'

  # sleep
  sleep 60

  # get peer
  rsync -avP root@nginx.dockr.life:/opt/wireguard/peer1/peer1.conf .
  #rsync -avP peer1.conf root@client.dockr.life:/opt/wireguard/wg0.conf

  # load peer into secret

  # configure keycloak
  # get auth token - notice keycloak's password 
  export key_token=$(curl -sk -X POST https://keycloak.$domain/auth/realms/master/protocol/openid-connect/token -d 'client_id=admin-cli&username=admin&password='$password'&credentialId=&grant_type=password' | jq -r .access_token)

  # add realm
  curl -sk -X POST https://keycloak.$domain/auth/admin/realms -H "authorization: Bearer $key_token" -H 'accept: application/json, text/plain, */*' -H 'content-type: application/json;charset=UTF-8' -d '{"enabled":true,"id":"stackrox","realm":"stackrox"}'

  # add client
  curl -sk -X POST https://keycloak.$domain/auth/admin/realms/stackrox/clients -H "authorization: Bearer $key_token" -H 'accept: application/json, text/plain, */*' -H 'content-type: application/json;charset=UTF-8' -d '{"enabled":true,"attributes":{},"redirectUris":[],"clientId":"stackrox","protocol":"openid-connect","publicClient": false,"redirectUris":["https://'$ROX_URL'/sso/providers/oidc/callback"]}'
  #,"implicitFlowEnabled":true

  # get client id
  export client_id=$(curl -sk  https://keycloak.$domain/auth/admin/realms/stackrox/clients/ -H "authorization: Bearer $key_token"  | jq -r '.[] | select(.clientId=="stackrox") | .id')

  # get client_secret
  export client_secret=$(curl -sk  https://keycloak.$domain/auth/admin/realms/stackrox/clients/$client_id/client-secret -H "authorization: Bearer $key_token" | jq -r .value)

  # add keycloak user clemenko / Pa22word
  curl -k https://keycloak.$domain/auth/admin/realms/stackrox/users -H 'Content-Type: application/json' -H "authorization: Bearer $key_token" -d '{"enabled":true,"attributes":{},"groups":[],"credentials":[{"type":"password","value":"Pa22word","temporary":false}],"username":"clemenko","emailVerified":"","firstName":"Andy","lastName":"Clemenko"}' 

  # copy script to client
  rsync -avP $0 root@client.dockr.life:/opt/$0

  echo "$GREEN" "ok" "$NORMAL"
}

############################# login ###############################
function login () {
  echo " login "
  # install bits
  echo "10.13.13.1 nginx.dockr.life" >> /etc/hosts

  command -v wg >/dev/null 2>&1 || { apt install -y wireguard resolvconf; }

  # get creds
  echo -n " - username: "; read username
  echo -n " - password: "; read -s password; echo 

  # get token from auth

  # turn it on
  if [ -f /etc/wireguard/wg0.conf ]; then wg-quick up wg0
  else  echo " $RED no wireguard config file found. $NORMAL"; exit ; fi

  # test
  # curl nginx.dockr.life

  echo "$GREEN" "ok" "$NORMAL"
}

############################# logout ###############################
function logout () {
  echo -n " logout "
  wg-quick down wg0

  # test
  rm -rf /etc/wiregaurd/wg0.conf

  echo "$GREEN" "ok" "$NORMAL"
}

############################## kill ################################
#remove the vms
function kill () {
  echo -n " killing it all "
  doctl compute droplet delete --force nginx client
  for i in $(doctl compute domain records list $domain|grep 'nginx\|client'|awk '{print $1}'); do doctl compute domain records delete -f dockr.life $i; done
  ssh-keygen -q -R client.dockr.life > /dev/null 2>&1
  ssh-keygen -q -R nginx.dockr.life > /dev/null 2>&1
  echo "$GREEN" "ok" "$NORMAL"
}

############################# usage ################################
function usage () {
  echo ""
  echo "-------------------------------------------------"
  echo ""
  echo " Usage: $0 {up|kill|login|logout}"
  echo ""
  echo " $0 up # build the vms "
  echo " $0 login # login"
  echo " $0 logout # logout"
  echo " $0 kill # kill the vms"
  echo ""
  echo "-------------------------------------------------"
  echo ""
  exit 1
}

# main 

case "$1" in
        up) setup;;
        kill) kill;;
        login) login;;
        logout) logout;;
        *) usage;;
esac