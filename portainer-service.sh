#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="portainer-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# SERVICE INFO --------------------------------------
DEFAULT_PORT=20000
DEFAULT_SERVICE_NAME="portainer-service"

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE="portainer/portainer"
DEFAULT_DOCKER_IMAGE_VERSION="latest"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "portainer service as a docker container for managing container"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--version=<version>] [--port=<port>] [-- additional docker run options] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start : start service"
  echo "L     stop : stop service"
  echo "L     destroy [--version=<version>] : stop, delete service and all image files. At next create, everything will be forced to be downloaded."
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "o-- options :"
  echo "L     --port : portainer listening port"
  echo "L     --version : portainer image version"
  echo "L     --debug : active some debug trace"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy'
"
OPTIONS="
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening port.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  portainer image version .
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"

# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME
SERVICE_DATA_NAME="$SERVICE_NAME"

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"

# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  # delete previously stored container
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

  __log_run docker run -d \
              --name $SERVICE_NAME \
              --restart always \
              -p $PORT:9000 \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -v $SERVICE_DATA_NAME:/data \
              $APPARG $DOCKER_URI
fi

if [ "$ACTION" = "destroy" ]; then
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  __log_run docker rmi $DOCKER_URI 2>/dev/null
  __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
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
