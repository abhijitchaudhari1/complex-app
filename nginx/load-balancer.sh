#!/bin/bash 
while getopts ":e:c:s:p:" OPTION
do
	case $OPTION in
		c)
		 	colour="${OPTARG:-blue}"
			;;
		s)
			swarm_cluster_name="${OPTARG:-master-2}"
			;;
		p)
			primary="${OPTARG:-master-1}"
			;;
		e)
			ETCD="${OPTARG}"
	esac
done
colour="${colour:-blue}"
swarm_cluster_name="${swarm_cluster_name:-master-2}"
primary="${primary:-master-1}"
ETCD="${ETCD:-104.131.180.93:5002}"
if [ $colour == "blue" ]
	then
	opp_colour="green"
else
	opp_colour="blue"
fi
count=1
#colour=blue
##Set app name to current directory name
app=$(basename `pwd` | tr -d '-')
#Set this value to the swarm cluster name which you can see "docker-machine ls"
#Set this either while running the script like ./script "swarm-cluster-name"  or edit directly into the file 
#swarm_cluster_name="${1:-master-2}"
#Set this values the current primary node of swarm cluster 
#Set this either while running the script like  ./script "swarm-cluster-name" "primary-name" or edit directly into the file 
#primary="${2:-master-1}" 
#Set Nginx load balancer port
port=80
##Set the network name using name of current directory
net=${app}_default
#change the environment to swarm primary to get all members of swarm cluster
eval $(docker-machine env --swarm $primary )
#Get all members of swarm cluster
machine=`docker-machine ls --filter state=Running --filter swarm=$swarm_cluster_name | awk '{ if (NR!=1) {print $1}}'`
#Create docker file for nginx ad load balacner 
echo 'RlJPTSBuZ2lueDpsYXRlc3QKTUFJTlRBSU5FUiBBYmhpaml0IENoYXVkaGFyaSA8YWJoaWppdC5j
aGF1ZGhhcmlAaW5pdGNyb24ub3JnPgoKUlVOIHJtIC9ldGMvbmdpbngvY29uZi5kL2RlZmF1bHQu
Y29uZgpBREQgZGVmYXVsdC5jb25mIC9ldGMvbmdpbngvY29uZi5kLwoKRVhQT1NFIDgwCg==' | base64 --decode > nginx/Dockerfile

#Remove the default.conf of already exists
rm -rf nginx/default.conf

#Create the default.conf for nginx site 
echo 'upstream api {' >> nginx/default.conf
#Get IPs of add api containers
api_cont=`docker network inspect    ${net} | grep "${app}_api-${colour}_" -A 3 | grep 'IPv4Address' | cut -d'"' -f4 | cut -d'/' -f 1`
opp_api_cont_IDs=`docker ps | grep "${app}_api-${opp_colour}_" | awk '{print $1}'`
#Write the API container IPS to default.conf for nginx site 
for api_mem in $api_cont ; do    echo "server ${api_mem}:8080;" >> nginx/default.conf; done
echo "}" >> nginx/default.conf
echo 'upstream admin {' >> nginx/default.conf
#Get IPs of add admin containers
admin_cont=`docker network inspect    ${net} | grep "${app}_administration-${colour}_" -A 3 | grep 'IPv4Address' | cut -d'"' -f4 | cut -d'/' -f 1`
opp_admin_cont_IDs=`docker ps | grep "${app}_administration-${opp_colour}_" | awk '{print $1}'`
#Write the admin container IPS to default.conf for nginx site 
for admin_mem in $admin_cont ; do    echo "server ${admin_mem}:8080;" >> nginx/default.conf; done
#echo 'fQpzZXJ2ZXIgewogICAgbGlzdGVuIDgwIDsKICAgIHNlcnZlcl9uYW1lIGxvY2FsaG9zdDsKCiAgICBsb2NhdGlvbiAvYXBpIHsKICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9hcGkvOwogICAgfQogICAgbG9jYXRpb24gL2FkbWluIHsKICAgICAgICBwcm94eV9wYXNzIGh0dHA6Ly9hZG1pbi87CiAgICB9Cn0K' | base64 --decode >> nginx/default.conf
cat >> nginx/default.conf << EOF
}
server {
    listen ${port} ;
    server_name localhost;

    location /api {
        proxy_pass http://api/;
    }
    location /admin {
        proxy_pass http://admin/;
    }
}
EOF

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
	echo "Launching the load balancer (load-balancer-${count}) container for first time on node:${launch_node}"
	docker run  --name load-balancer-${count} -d  -p ${port}:${port} --net=${net}   --env="constraint:node==${launch_node}" lb:latest
else
	#launch the container only if the build image has any changes compared to old one 
	if  [ $new != $old ] 
		then 
		echo "load balancer image has changed on node ${launch_node} "
		CID=$(docker ps | grep "${launch_node}/load-balancer-${count}" | grep "${port}" | awk '{print $1}')
		if [ ! -z $CID ]
			then
				echo "deleting the old load-balancer-${count} on node:${launch_node} "
				docker stop $CID
				docker rm $CID
		fi
				echo "Launching the load balancer (load-balancer-${count}) container on node:${launch_node} "
				docker run  --name load-balancer-${count} -d  -p ${port}:${port} --net=${net}  --env="constraint:node==${launch_node}" lb:latest
	else
		echo "No change Found in the load balancer image on node:${launch_node}"
		echo "Testing wheather load-balancer container is running"
		unset CID
		CID=$(docker ps | grep "${launch_node}/load-balancer-${count}" | grep "${port}" | awk '{print $1}')
		if [ -z $CID ]
			then
			echo "Did not find the running load-balancer container on node ${launch_node} !!!!!"
			echo "Launching the new container NOW"
			docker run  --name load-balancer-${count} -d  -p ${port}:${port} --net=${net}  --env="constraint:node==${launch_node}" lb:latest
		else
			echo "Load balancer container is already running with container ID=${CID}"
		fi	
	fi 

fi
count=$(( count + 1 ))
done
if [ ! -z  $opp_api_cont_IDs ]
	then
	echo "Stopping the api container in ${opp_colour}"
	docker stop ${opp_api_cont_IDs}
fi
if [ ! -z  $opp_admin_cont_IDs ]
	then
	echo "Stopping the admin container in ${opp_colour}"
	docker stop ${opp_admin_cont_IDs}
fi

echo "Setting the running as colour to ${colour} in  ETCD"
curl -L -X PUT http://${ETCD}/v2/keys/colour -d value="${colour}"




