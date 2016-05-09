#!/bin/bash 
while getopts ":e:s:p:" OPTION
do
	case $OPTION in
		e)
		 	ETCD="${OPTARG:-104.131.180.93:5002}"
			;;
		s)
			swarm_cluster_name="${OPTARG:-master-2}"
			;;
		p)
			primary="${OPTARG:-master-1}"
			;;
	esac
done
	
swarm_cluster_name="${swarm_cluster_name:-master-2}"
primary="${primary:-master-1}"
ETCD="${ETCD:-104.131.180.93:5002}"
curl -L  http://${ETCD}/v2/keys/colour   | grep -v 'grep' | grep 'errorCode'
if [ $? != 0 ]
	then
		colour=`curl -L  http://104.131.180.93:5002/v2/keys/colour | awk -F'value' '{print $2}' | cut -d'"' -f 3`
	else
		echo "colour key in ETCD not Found, setting colour=green in order to deploy in 'blue' for first time"
		colour="green"
	fi


if [ $colour == "blue" ]
	then
	opp_colour="green"
else
	opp_colour="blue"
fi

echo "Deploying the app on ${opp_colour}"

docker-compose up -d --build mongodb redis api-${opp_colour} administration-${opp_colour}

echo "Creating load balancers for the app deployed in ${opp_colour}"

nginx/load-balancer.sh -c "${opp_colour}" -s "${swarm_cluster_name}" -p "${primary}" -e "${ETCD}"



