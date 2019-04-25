#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="netdata-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://github.com/firehol/netdata
# https://github.com/titpetric/netdata

# SERVICE INFO --------------------------------------
DEFAULT_PORT=19999
DEFAULT_IP="0.0.0.0"
DEFAULT_SERVICE_NAME="netdata-service"

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE="titpetric/netdata"
DEFAULT_DOCKER_IMAGE_VERSION="latest"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "netdata service as a docker container for monitoring current host"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--version=<version>] [--ip=<ip>] [--port=<port>] [-- additional docker run options] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start : start service"
  echo "L     stop : stop service"
  echo "L     destroy [--version=<version>] : stop, delete service and all image files. At next create, everything will be forced to be downloaded."
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "o-- options :"
  echo "L     --port : netdata listening port"
  echo "L     --ip : netdata listening ip (Use --ip OR --if. --if have priority)"
  echo "L     --if : netdata listening network interface (Use --ip OR --if. --if have priority)"
  echo "L     --version : netdata version"
  echo "L     --debug : active some debug trace"
  echo "L     --netdataarg : netdata options passed to netdata binary command line"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy'  '1'
"
OPTIONS="
IP='$DEFAULT_IP' 						'' 			'string'				s 			0			''		  Listening netdata ip.
IF='' 						'' 			'string'				s 			0			''		  Listening netdata network interface.
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening netdata port.
NETDATAARG='' 						'' 			'string'				s 			0			''		  Netdata options passed to netdata binary command line.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "DOCKERARG" "$@"


# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"

# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  # delete previously stored container
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null

  [ ! "$IF" = "" ] && IP="$($STELLA_API get_ip_from_interface $IF)"

  __log_run docker run -d \
              --name $SERVICE_NAME \
              --restart always \
              --cap-add SYS_PTRACE \
              -v /proc:/host/proc:ro \
              -v /sys:/host/sys:ro \
              -e NETDATA_PORT=$PORT \
              -e NETDATA_IP=$IP \
              -e NETDATA_ARGS=${NETDATAARG} \
              --net=host \
              -v /var/run/docker.sock:/var/run/docker.sock \
              $DOCKERARG $DOCKER_URI

fi

if [ "$ACTION" = "destroy" ]; then
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
