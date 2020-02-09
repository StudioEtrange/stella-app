#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="consul-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# NOTE : consul agent server expect only 1 agent server to do the quorum. It is recommanded to use at least 3
# on consul agent server, an UI is activated, see http://host:8500/ui

# Example with docker-machine
# docker-machine create test
# eval $(docker-machine env test)
# ./consul-service.sh create 1 server -d --http=8500 --ip=$(docker-machine ip $DOCKER_MACHINE_NAME)
# docker logs consul-service-1
# see http://$(docker-machine ip $DOCKER_MACHINE_NAME):8500/ui

# Example with macos docker desktop
# ./consul-service.sh create 1 server -m
# ./consul-service.sh create 2 client -m --joinid=1
# ./consul-service.sh list 1 members


# NOTE :
# Consul should be run with --net=host in Docker because Consul's consensus and gossip protocols are sensitive to delays and packet loss,
# so the extra layers involved with other networking types are usually undesirable and unnecessary.

# NOTE : 
#    - CONSUL_CLIENT_INTERFACE and/or CONSUL_BIND_INTERFACE could be use to specify interface
#    - "disable_update_check": true ==> disable HTTP request to hashicorp to check critical update


# SERVICE INFO --------------------------------------
DEFAULT_HTTP_PORT=8500
DEFAULT_DNS_PORT=8600

DEFAULT_SERVICE_NAME="consul-service"

# DOCKER IMAGES INFO --------------------------------------
# https://github.com/hashicorp/docker-consul
DEFAULT_DOCKER_IMAGE="consul"
DEFAULT_DOCKER_IMAGE_VERSION="1.0.6"



# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Consul service as docker instance on current host"
  echo "NOTE : require docker on your system"
  echo "NOTE : it cand provide a server consul agent or a client only consul agent"
  echo "----------------"
  echo "o-- command :"
  echo "L     create <id> <server> [--version=<version>] [--http=<port>] [--dns=<port>] [--ip=<ip>|--if=<interface>] [--datacenter=<string>] [--domainname=<string>] [--nopurge] [-- additional docker run options] : create & launch service (must be use once before starting/stopping service)"
  echo "L     create <id> <client> [--version=<version>] [--joinip=<ip>|joinid=<id>]  [--http=<port>] [--dns=<port>] [--ip=<ip>|--if=<interface>] [--datacenter=<string>] [--domainname=<string>] [--nopurge] [-- additional docker run options] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start <id> : start service"
  echo "L     stop <id> : stop service"
  echo "L     status <id> : give service status info"
  echo "L     shell <id> : launch a shell inside running service"
  echo "L     destroy <id> [--version=<version>] [--nopurge] : destroy service"
  echo "L     logs <id> : give service status info"
  echo "L     list <id> members : will list consul cluster members, by connecting to an agent <id> (1 by default)"
  echo "L     purgedata <id> : erase any internal data volume attached to the service and/or folder storing data on host"
  echo "o-- options :"
  echo "L     --http : consul http api port"
  echo "L     --dns : consul dns port"
  echo "L     --version : consul image version"
  echo "L     --ip : ip on which all consul agent services will listen. (Use --if or --ip. --if have priority)"
  echo "L     --if : interface on which all consul agent services will listen (Use --if or --ip, --if have priority)"
  echo "L     --joinip : ip of a consul server agent which the client will join (usefull only with <client>)"
  echo "L     --debug : active some debug trace"
  echo "L     --datacenter : consul datacenter name"
  echo "L     --domain : consul domain name"
  echo "L     --nopurge : do not erase any internal data volume attached to service while create/destroy"
  echo "L     --macdesk : Active a specific behaviour for macos docker desktop support. Will ignore any ip, if options. Will keep HTTP and DNS port options for server but ignore them for client."

}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy list purgedata logs' '1'
ID=											'' 			s				'' '0'
TARGET=											'' 			a				'client server members' '0'
"
OPTIONS="
HTTP='$DEFAULT_HTTP_PORT' 						'' 			'string'				s 			0			''		  Consul http api port.
DNS='$DEFAULT_DNS_PORT' 						'' 			'string'				s 			0			''		  Consul dns port.
IP='' 						'' 			'string'				s 			0			''		  IP on which all consul agent services will listen. Use --if or --ip, if both used --ip is used.
IF='' 						'' 			'string'				s 			0			''		  Interface on which all consul agent services will listen. Use --if or --ip, if both used --ip is used.
JOINIP='' 						'' 			'string'				s 			0			''		  IP of a consul server agent which the client will join.
JOINID='' 						'' 			'string'				s 			0			''		  ID of a consul server agent which the client will join.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Consul image version.
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
DATACENTER='' 			'' 			'string'				s 			0			''		  Consul datacenter name.
DOMAINNAME='' 			'' 			'string'				s 			0			''		  Consul domain name.
NOPURGE=''            'n'    		''            		b     		0     		'1'           			Do not erase any internal data volume attached to service while create/destroy.
MACDESK=''            'm'    		''            		b     		0     		'1'           			Special tag to active a specific behaviour for macos docker desktop support. Will ignore any ip, if options. Will keep HTTP and DNS port options for server but ignore them for client.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "EXTRA_ARG DOCKERARG" "$@"


# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

# TODO : migrate to stella api (this function exist inside stella api)
# work even if we pass an ip
__get_ip_from_hostname() {
	type getent &>/dev/null
	if [ $? = 0 ]; then
		echo "$(getent ahostsv4 $1 | grep STREAM | head -n 1 | cut -d ' ' -f 1)"
	else
		echo "$(ping -q -c 1 -t 1 $1 2>/dev/null | grep -m 1 PING | cut -d "(" -f2 | cut -d ")" -f1)"
	fi
}

# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
[ "$ID" = "" ] && ID="1"
DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME="${DEFAULT_SERVICE_NAME}"
SERVICE_NAME"=${SERVICE_NAME}-${ID}"
SERVICE_DATA_NAME="${SERVICE_NAME}"



# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"


# ------------- ACTIONS -------------------------

if [ "$ACTION" = "list" ]; then
  case $TARGET in
    members )
       __log_run docker exec -t $SERVICE_NAME consul members
    ;;
  esac
fi



if [ "$ACTION" = "create" ]; then
    # delete and stop previously stored container and volume
    __log_run docker stop $SERVICE_NAME 2>/dev/null
    __log_run docker rm $SERVICE_NAME 2>/dev/null
    [ ! "${NOPURGE}" = "1" ] && __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

    case $TARGET in
      server )
        _OPT=
        [ ! "$DATACENTER" = "" ]  && _OPT="$_OPT -datacenter=$DATACENTER"
        [ ! "$DOMAINNAME" = "" ]  && _OPT="$_OPT -domain=$DOMAINNAME"

        # for macos docker desktop
        # https://stackoverflow.com/questions/41228968/accessing-consul-ui-running-in-docker-on-osx
        # NOTE : template for infer adress https://github.com/hashicorp/go-sockaddr/tree/master/cmd/sockaddr    
        if [ "$MACDESK" = "1" ]; then
          __log_run docker run -d \
            --name $SERVICE_NAME \
            -p $HTTP:8500 -p $DNS:8600 -P \
            --restart always \
            -v $SERVICE_DATA_NAME:/consul/data \
            -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true, "disable_update_check": true}' \
            $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=8500 -dns-port=8600 \
            -server -bootstrap-expect=1 -ui -bind='{{ GetPrivateIP }}' -client=0.0.0.0

        else

          
          if [ ! "$IP" = "" ]; then

            CONSUL_AGENT_BIND_IP="$(__get_ip_from_hostname $IP)"

            __log_run docker run -d \
                --name $SERVICE_NAME \
                --restart always \
                --net=host \
                -v $SERVICE_DATA_NAME:/consul/data \
                -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true, "disable_update_check": true}' \
                $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
                -server -bootstrap-expect=1 -ui \
                -bind=$CONSUL_AGENT_BIND_IP -client=$CONSUL_AGENT_BIND_IP \
                $_OPT
          else
            if [ ! "$IF" = "" ]; then
              __log_run docker run -d \
                  --name $SERVICE_NAME \
                  --restart always \
                  --net=host \
                  -v $SERVICE_DATA_NAME:/consul/data \
                  -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true, "disable_update_check": true}' \
                  -e CONSUL_BIND_INTERFACE=$IF -e CONSUL_CLIENT_INTERFACE=$IF \
                  $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
                  -server -bootstrap-expect=1 -ui \
                  $_OPT
              else
                __log_run docker run -d \
                  --name $SERVICE_NAME \
                  --restart always \
                  --net=host \
                  -v $SERVICE_DATA_NAME:/consul/data \
                  -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true, "disable_update_check": true}' \
                  $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
                  -server -bootstrap-expect=1 -ui \
                  $_OPT

              fi
          fi
        fi
        ;;




      client )

        # convert hostname to IP
        [ ! "$JOINIP" = "" ] && JOINIP="$(__get_ip_from_hostname $JOINIP)"
        if [ ! "$JOINID" = "" ]; then
              JOINIP="$(docker inspect -f '{{.NetworkSettings.IPAddress}}' ${DEFAULT_SERVICE_NAME}-${JOINID})"
        fi

        if [ "$JOINIP" = "" ]; then
          echo "** ERROR : precise a consul IP to join with --joinip or an instance id with --joinid"
          exit 1
        fi

        if [ "$MACDESK" = "1" ]; then

          __log_run docker run -d \
            --name $SERVICE_NAME \
            -P \
            --restart always \
            -v $SERVICE_DATA_NAME:/consul/data \
            -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true, "disable_update_check": true}' \
            $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=8500 -dns-port=8600 \
            -retry-join=$JOINIP -bind='{{ GetPrivateIP }}' -client=0.0.0.0

        else
        

          if [ ! "$IP" = "" ]; then
            CONSUL_AGENT_BIND_IP="$(__get_ip_from_hostname $IP)"

            __log_run docker run -d \
              --name $SERVICE_NAME \
              --restart always \
              --net=host \
              -v $SERVICE_DATA_NAME:/consul/data \
              -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true, "disable_update_check": true}' \
              $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
              -retry-join=$JOINIP -bind=$CONSUL_AGENT_BIND_IP -client=$CONSUL_AGENT_BIND_IP
          else
            if [ ! "$IF" = "" ]; then
              __log_run docker run -d \
                --name $SERVICE_NAME \
                --restart always \
                --net=host \
                -v $SERVICE_DATA_NAME:/consul/data \
                -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true, "disable_update_check": true}' \
                -e CONSUL_BIND_INTERFACE=$IF -e CONSUL_CLIENT_INTERFACE=$IF \
                $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
                -retry-join=$JOINIP
            else
              __log_run docker run -d \
                --name $SERVICE_NAME \
                --restart always \
                --net=host \
                -v $SERVICE_DATA_NAME:/consul/data \
                -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true, "disable_update_check": true}' \
                $DOCKERARG $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
                -retry-join=$JOINIP
            fi
          fi
        fi
        ;;


    esac
fi

if [ "$ACTION" = "start" ]; then
    __log_run docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
    __log_run docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
  __log_run docker ps -a | grep $SERVICE_NAME
  __log_run docker stats --no-stream $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
    __log_run docker exec -it $SERVICE_NAME sh
fi

if [ "$ACTION" = "destroy" ]; then
  # remove cntainers
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  [ ! "${NOPURGE}" = "1" ] && __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
  # remove image
  __log_run docker rmi $DOCKER_URI 2>/dev/null
fi


if [ "$ACTION" = "purgedata" ]; then
  __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
fi


if [ "$ACTION" = "logs" ]; then
  __log_run docker logs $SERVICE_NAME
fi