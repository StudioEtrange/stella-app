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

function usage() {
	echo "USAGE :"
  echo "deploy netdata in a docker instance for monitoring current host"
	echo "NOTE : require docker on your system"
	echo "----------------"
	echo "o-- parametres :"
  echo "L     create [--version=<version>] [--ip=<ip>] [--port=<port>]: create & launch netdata service (must be use once before starting/stopping service)"
	echo "L     start [--version=<version>] : start netdata service"
  echo "L     stop [--version=<version>] : stop netdata service"
  echo "L     status : give service status info"
	echo "o-- options :"
	echo "L     --port : netdata listening port"
	echo "L     --ip : netdata listening ip"
	echo "L     --version : netdata version"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status'
"
OPTIONS="
IP='$DEFAULT_IP' 						'' 			'string'				s 			0			''		  Listening ip.
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening port.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_URI=$DEFAULT_DOCKER_IMAGE:$VERSION
DEFAULT_SERVICE_NAME="netdata-service"
SERVICE_NAME=$DEFAULT_SERVICE_NAME-$VERSION

# test docker engine is installed in this system
$STELLA_API require "dockerd" "SYSTEM"


# https://github.com/titpetric/netdata
if [ "$ACTION" = "create" ]; then
	docker rm $SERVICE_NAME 2>/dev/null
  docker run -d --cap-add SYS_PTRACE \
              -v /proc:/host/proc:ro \
              -v /sys:/host/sys:ro \
              -e NETDATA_PORT=$PORT \
							-e NETDATA_IP=$IP \
              --net=host \
              -v /var/run/docker.sock:/var/run/docker.sock \
              --name "$SERVICE_NAME" \
              $DOCKER_URI

fi

if [ "$ACTION" = "start" ]; then
  docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
  docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
  docker ps | grep $DEFAULT_SERVICE_NAME
fi
