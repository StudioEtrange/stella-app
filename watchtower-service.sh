#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="netdata-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://github.com/containrrr/watchtower

# SERVICE INFO --------------------------------------
DEFAULT_SERVICE_NAME="watchtower-service"

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE="containrrr/watchtower"
DEFAULT_DOCKER_IMAGE_VERSION="latest"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "watchtower service as a docker container for refreshing current running container"
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
  echo "L     --version : watchtower version"
  echo "L     --debug : active some debug trace"
  echo "L     --opt : watchtower options passed to netdata binary command line"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy'  '1'
"
OPTIONS="
OPT='' 						'' 			'string'				s 			0			''		  watchtower options passed to netdata binary command line.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "EXTRA_ARG " "$@"


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

[ "$DEBUG" = "1" ] && OPT="${OPT} --debug"


# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"

# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  # delete previously stored container
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null


  __log_run docker run -d \
              --name $SERVICE_NAME \
              --restart always \
              -v /var/run/docker.sock:/var/run/docker.sock \
              $DOCKERARG $DOCKER_URI $OPT

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
  __log_run docker ps | grep $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
  __log_run docker exec -it $SERVICE_NAME sh
fi
