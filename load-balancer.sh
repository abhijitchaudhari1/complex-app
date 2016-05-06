#!/bin/bash 
count=1
#Set this value to the swarm cluster name which you can see "docker-machine ls"
#Set this either while running the script like ./script "swarm-cluster-name"  or edit directly into the file 
swarm="${1:-master-2}"
#Set this values the current primary node of swarm cluster 
#Set this either while running the script like  ./script "swarm-cluster-name" "primary-name" or edit directly into the file 
primary="${2:-master-1}" 
eval $(docker-machine env --swarm $primary )
machine=`docker-machine ls --filter state=Running --filter swarm=$swarm | awk '{ if (NR!=1) {print $1}}'`
echo 'RlJPTSBuZ2lueDpsYXRlc3QKTUFJTlRBSU5FUiBBYmhpaml0IENoYXVkaGFyaSA8YWJoaWppdC5j
aGF1ZGhhcmlAaW5pdGNyb24ub3JnPgoKUlVOIHJtIC9ldGMvbmdpbngvY29uZi5kL2RlZmF1bHQu
Y29uZgpBREQgZGVmYXVsdC5jb25mIC9ldGMvbmdpbngvY29uZi5kLwoKRVhQT1NFIDgwCg==' | base64 --decode > Dockerfile
rm -rf default.conf
echo 'upstream api {' >> default.conf
api_cont=`docker network inspect    complexapp_default | grep 'complexapp_api_' -A 3 | grep 'IPv4Address' | cut -d'"' -f4 | cut -d'/' -f 1`
for api_mem in $api_cont ; do    echo "server ${api_mem}:8080;" >> default.conf; done
echo "}" >> default.conf
echo 'upstream admin {' >> default.conf
admin_cont=`docker network inspect    complexapp_default | grep 'complexapp_administration_' -A 3 | grep 'IPv4Address' | cut -d'"' -f4 | cut -d'/' -f 1`
for admin_mem in $admin_cont ; do    echo "server ${admin_mem}:8080;" >> default.conf; done
echo 'fQpzZXJ2ZXIgewogICAgbGlzdGVuIDgwIDsKICAgIHNlcnZlcl9uYW1lIGxvY2FsaG9zdDsKCiAgICBsb2NhdGlvbiAvYXBpIHsKICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9hcGkvOwogICAgfQogICAgbG9jYXRpb24gL2FkbWluIHsKICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9hZG1pbi87CiAgICB9Cn0K' | base64 --decode >> default.conf
for launch_node in $machine
do 
eval $(docker-machine env $launch_node )
old=`docker images  | grep 'lb'  | awk '{print $3}'`
new=`docker build -t lb:latest . | tail -n 1 |awk '{print $3}'`
eval $(docker-machine env --swarm $primary )
#docker ps | grep "${launch_node}/load-balancer" | grep 80
if [ -z $old ]  
	then
	docker run  --name load-balancer-${count} -d  -p 80:80 --net=complexapp_default   --env="constraint:node==${launch_node}" lb:latest
else
	if  [ $new != $old ] 
		then 
		CID=$(docker ps | grep "${launch_node}/load-balancer" | grep 80 | awk '{print $1}')
		docker stop $CID
		docker rm $CID
		docker run  --name load-balancer-${count} -d  -p 80:80 --net=complexapp_default   --env="constraint:node==${launch_node}" lb:latest
	fi
fi
count=$(( count + 1 ))
done

