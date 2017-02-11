#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="netdata-deploy.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


DEFAULT_PORT=19999
DEFAULT_DOCKER_IMAGE="titpetric/netdata"
DEFAULT_DOCKER_IMAGE_VERSION="1.5"

function usage() {
	echo "USAGE :"
  echo "deploy netdata in a docker instance for monitoring current host"
	echo "----------------"
	echo "o-- parametres :"
	echo "L     YYYY-MM-DD YYYY-MM-DD : date debut et date fin (incluses)"
	echo "o-- options :"
	echo "L			--port : netdata listening port"
	echo "L     --version : sortie elasticsearch host"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'install run stop status'
"
OPTIONS="
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening port.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_URI=$DEFAULT_DOCKER_IMAGE:$VERSION
DOCKER_NAME="netdata-deploy"


if [ "$ACTION" = "install" ]; then
  $STELLA_API feature_install docker#1_12_6
  docker pull $DOCKER_URI
fi


# https://github.com/titpetric/netdata
if [ "$ACTION" = "run" ]; then
  docker run -d --cap-add SYS_PTRACE \
              -v /proc:/host/proc:ro \
              -v /sys:/host/sys:ro \
              -p $PORT:19999 \
              --net=host \
              -v /var/run/docker.sock:/var/run/docker.sock \
              --name "$DOCKER_NAME" \
              $DOCKER_URI

fi


if [ "$ACTION" = "stop" ]; then
  docker stop $DOCKER_NAME
fi


if [ "$ACTION" = "status" ]; then
  docker ps
fi
