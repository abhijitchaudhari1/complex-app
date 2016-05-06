#!/bin/bash -e
count=1
#Set this value to the swarm cluster name which you can see "docker-machine ls"
#Set this either while running the script like ./script "swarm-cluster-name"  or edit directly into the file 
swarm="${1:-master-2}"
#Set this values the current primary node of swarm cluster 
#Set this either while running the script like  ./script "swarm-cluster-name" "primary-name" or edit directly into the file 
primary="${2:-master-1}" 

#change the environment to swarm primary to get all members of swarm cluster
eval $(docker-machine env --swarm $primary )
#Get all members of swarm cluster
machine=`docker-machine ls --filter state=Running --filter swarm=$swarm | awk '{ if (NR!=1) {print $1}}'`
#Create docker file for nginx ad load balacner 
echo 'RlJPTSBuZ2lueDpsYXRlc3QKTUFJTlRBSU5FUiBBYmhpaml0IENoYXVkaGFyaSA8YWJoaWppdC5j
aGF1ZGhhcmlAaW5pdGNyb24ub3JnPgoKUlVOIHJtIC9ldGMvbmdpbngvY29uZi5kL2RlZmF1bHQu
Y29uZgpBREQgZGVmYXVsdC5jb25mIC9ldGMvbmdpbngvY29uZi5kLwoKRVhQT1NFIDgwCg==' | base64 --decode > nginx/Dockerfile

#Remove the default.conf of already exists
rm -rf nginx/default.conf

#Create the default.conf for nginx site 
echo 'upstream api {' >> nginx/default.conf
#Get IPs of add api containers
api_cont=`docker network inspect    complexapp_default | grep 'complexapp_api_' -A 3 | grep 'IPv4Address' | cut -d'"' -f4 | cut -d'/' -f 1`
#Write the API container IPS to default.conf for nginx site 
for api_mem in $api_cont ; do    echo "server ${api_mem}:8080;" >> nginx/default.conf; done
echo "}" >> nginx/default.conf
echo 'upstream admin {' >> nginx/default.conf
#Get IPs of add admin containers
admin_cont=`docker network inspect    complexapp_default | grep 'complexapp_administration_' -A 3 | grep 'IPv4Address' | cut -d'"' -f4 | cut -d'/' -f 1`
#Write the admin container IPS to default.conf for nginx site 
for admin_mem in $admin_cont ; do    echo "server ${admin_mem}:8080;" >> nginx/default.conf; done
echo 'fQpzZXJ2ZXIgewogICAgbGlzdGVuIDgwIDsKICAgIHNlcnZlcl9uYW1lIGxvY2FsaG9zdDsKCiAgICBsb2NhdGlvbiAvYXBpIHsKICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9hcGkvOwogICAgfQogICAgbG9jYXRpb24gL2FkbWluIHsKICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9hZG1pbi87CiAgICB9Cn0K' | base64 --decode >> nginx/default.conf


#launch load balancer container on each swarm member
for launch_node in $machine
do 
#change the environment to each node to build the load balancer image on it 
eval $(docker-machine env $launch_node )
#GEt the images id for load balancer image if exists
old=`docker images  | grep 'lb'  | awk '{print $3}'`
#GEt the images id for load balancer image created just now
new=`docker build -t lb:latest nginx/ | tail -n 1 |awk '{print $3}'`
#change the environment to swarm primary to launch the container on each swarm node
eval $(docker-machine env --swarm $primary )
# launch the container directly if old images does not exist, which means this is the first time, so no need to check/delete as running container
if [ -z $old ]  
	then
	echo "Launching the load balancers(load-balancer-${count}) container for first time on node:${launch_node}"
	docker run  --name load-balancer-${count} -d  -p 80:80 --net=complexapp_default   --env="constraint:node==${launch_node}" lb:latest
else
	#launch the container only if the build image has any changes compared to old one 
	if  [ $new != $old ] 
		then 
		echo "Deleting the existing load balancer container  on node:${launch_node} as images has changed  and launching  new load balancer(load-balancer-${count}) on node:${launch_node}"
		CID=$(docker ps | grep "${launch_node}/load-balancer" | grep 80 | awk '{print $1}')
		docker stop $CID
		docker rm $CID
		docker run  --name load-balancer-${count} -d  -p 80:80 --net=complexapp_default   --env="constraint:node==${launch_node}" lb:latest
	else
		echo "Skipping as there is no change in the load balancer image on node:${launch_node}"
	fi 

fi
count=$(( count + 1 ))
done

