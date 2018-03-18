#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="netdata-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://github.com/firehol/netdata
# https://github.com/titpetric/netdata

DEFAULT_PORT=19999
DEFAULT_IP="0.0.0.0"
DEFAULT_DOCKER_IMAGE="titpetric/netdata"
DEFAULT_DOCKER_IMAGE_VERSION="latest"
DEFAULT_SERVICE_NAME="netdata-service"

function usage() {
  echo "USAGE :"
  echo "netdata service as a docker container for monitoring current host"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--version=<version>] [--ip=<ip>] [--port=<port>] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start : start service"
  echo "L     stop : stop service"
  echo "L     purge [--version=<version>] : stop, delete service and all image files. At next create, everything will be forced to be downloaded."
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "o-- options :"
  echo "L     --port : netdata listening port"
  echo "L     --ip : netdata listening ip"
  echo "L     --version : netdata version"
  echo "L     --debug : active some debug trace"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell purge'
"
OPTIONS="
IP='$DEFAULT_IP' 						'' 			'string'				s 			0			''		  Listening netdata ip.
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening netdata port.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"

__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

# https://github.com/titpetric/netdata
if [ "$ACTION" = "create" ]; then
  # delete previously stored container
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null

  __log_run docker run -d \
              --name $SERVICE_NAME \
              --restart always \
              --cap-add SYS_PTRACE \
              -v /proc:/host/proc:ro \
              -v /sys:/host/sys:ro \
              -e NETDATA_PORT=$PORT \
              -e NETDATA_IP=$IP \
              --net=host \
              -v /var/run/docker.sock:/var/run/docker.sock \
              $DOCKER_URI

fi

if [ "$ACTION" = "purge" ]; then
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  __log_run docker rmi $DOCKER_URI 2>/dev/null
fi

if [ "$ACTION" = "start" ]; then
  __log_run docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
  __log_run docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
  #docker stats $SERVICE_NAME
  __log_run docker ps | grep $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
  __log_run docker exec -it $SERVICE_NAME sh
fi
