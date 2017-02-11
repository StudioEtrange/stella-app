#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="netdata-deploy.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


DEFAULT_PORT=19999
DEFAULT_DOCKER_IMAGE="titpetric/netdata"
DEFAULT_DOCKER_IMAGE_VERSION="latest"

function usage() {
	echo "USAGE :"
  echo "deploy netdata in a docker instance for monitoring current host"
	echo "NOTE : require docker on your system"
	echo "----------------"
	echo "o-- parametres :"
	echo "L     install : deploy netdata"
  echo "L     launch : launch netdata service (must be use once before starting/stopping service)"
	echo "L     start : start netdata service"
  echo "L     stop : stop netdata service"
  echo "L     status : give status info"
	echo "o-- options :"
	echo "L			--port : netdata listening port"
	echo "L     --version : netdata version"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'install launch start stop status'
"
OPTIONS="
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening port.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_URI=$DEFAULT_DOCKER_IMAGE:$VERSION
DOCKER_NAME="netdata-deploy"

# test docker engine is installed in this system
$STELLA_API require "dockerd" "SYSTEM"

if [ "$ACTION" = "install" ]; then
  docker pull $DOCKER_URI
fi


# https://github.com/titpetric/netdata
if [ "$ACTION" = "launch" ]; then
	docker rm $DOCKER_NAME 2>/dev/null
  docker run -d --cap-add SYS_PTRACE \
              -v /proc:/host/proc:ro \
              -v /sys:/host/sys:ro \
              -p $PORT:19999 \
              --net=host \
              -v /var/run/docker.sock:/var/run/docker.sock \
              --name "$DOCKER_NAME" \
              $DOCKER_URI

fi


if [ "$ACTION" = "start" ]; then
  docker start $DOCKER_NAME
fi

if [ "$ACTION" = "stop" ]; then
  docker stop $DOCKER_NAME
fi


if [ "$ACTION" = "status" ]; then
  docker ps
fi
