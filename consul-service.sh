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
# ./consul-service.sh create server 1 -d --http=8500 --ip=$(docker-machine ip $DOCKER_MACHINE_NAME)
# docker logs consul-service-server-1
# see http://$(docker-machine ip $DOCKER_MACHINE_NAME):8500/ui

DEFAULT_HTTP_PORT=8500
DEFAULT_DNS_PORT=8600
DEFAULT_PROXY_PORT=80
DEFAULT_IP=$STELLA_HOST_DEFAULT_IP


DEFAULT_DOCKER_IMAGE="consul"
DEFAULT_DOCKER_IMAGE_VERSION="latest"
DEFAULT_SERVICE_NAME="consul-service"

function usage() {
  echo "USAGE :"
  echo "Consul service as docker instance on current host"
  echo "NOTE : require docker on your system"
  echo "NOTE : it cand provide a server consul agent or a client only consul agent"
  echo "----------------"
  echo "o-- command :"
  echo "L     create <client|server> <id> [--version=<version>] [--http=<port>] [--dns=<port>] [--ip=<ip>] [--datacenter=<string>] [--domainname=<string>] [--consulip=<ip>]: create & launch service (must be use once before starting/stopping service)"
  echo "L     start <client|server> <id> [--version=<version>] : start service"
  echo "L     stop <client|server> <id> [--version=<version>] : stop service"
  echo "L     status <client|server> <id> : give service status info"
  echo "L     shell <client|server> <id> : launch a shell inside running service"
  echo "L     purge <client|server> <id> : purge service"
  echo "o-- options :"
  echo "L     --http : consul http api port"
  echo "L     --dns : consul dns port"
  echo "L     --version : consul image version"
  echo "L     --ip : ip on which all consul agent services will listen"
  echo "L     --consulip : ip of a consul server agent which the client will join"
  echo "L     --debug : active some debug trace"
  echo "L     --datacenter : consul datacenter name"
  echo "L     --domain : consul domain name"

}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell purge'
TARGET=											'' 			a				'client server'
ID=											'' 			s				''
"
OPTIONS="
HTTP='$DEFAULT_HTTP_PORT' 						'' 			'string'				s 			0			''		  Consul http api port.
DNS='$DEFAULT_DNS_PORT' 						'' 			'string'				s 			0			''		  Consul dns port.
IP='$DEFAULT_IP' 						'' 			'string'				s 			0			''		  IP on which all consul agent services will listen.
CONSULIP='$DEFAULT_IP' 						'' 			'string'				s 			0			''		  IP of a consul server agent which the client will join.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Consul image version.
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
DATACENTER='' 			'' 			'string'				s 			0			''		  Consul datacenter name.
DOMAINNAME='' 			'' 			'string'				s 			0			''		  Consul domain name.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME}-${TARGET}-${ID}

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"


__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}


if [ "$ACTION" = "create" ]; then
    # delete and stop previously stored container and volume
    __log_run docker stop $SERVICE_NAME 2>/dev/null
    __log_run docker rm $SERVICE_NAME 2>/dev/null

    case $TARGET in
      server )
        _OPT=
        [ ! "$DATACENTER" = "" ]  && _OPT="$_OPT -datacenter=$DATACENTER"
        [ ! "$DOMAINNAME" = "" ]  && _OPT="$_OPT -domain=$DOMAINNAME"

        __log_run docker run -d \
            --name $SERVICE_NAME \
            --net=host \
            -v $SERVICE_NAME:/consul/data \
            -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' \
            $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
            -server -bootstrap-expect=1 -ui \
            -bind=$IP -client=$IP $_OPT
        ;;

      client )
        __log_run docker run -d \
          --name $SERVICE_NAME \
          --net=host \
          -v $SERVICE_NAME:/consul/data \
          -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}' \
          $DOCKER_URI agent -node=$SERVICE_NAME -http-port=$HTTP -dns-port=$DNS \
          -retry-join=$CONSULIP -bind=$IP -client=$IP
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
    __log_run docker stats $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
    __log_run docker exec -it $SERVICE_NAME sh
fi

if [ "$ACTION" = "purge" ]; then
  # remove cntainers
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  # remove image
  __log_run docker rmi $DOCKER_URI 2>/dev/null
fi
