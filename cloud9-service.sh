#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="netdata-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://c9.io/
# https://hub.docker.com/r/sapk/cloud9/
# https://github.com/sapk/dockerfiles

DEFAULT_HTTP_PORT=20001
DEFAULT_WORKSPACE="$HOME"
DEFAULT_LOGIN=
DEFAULT_PASSWORD=

DEFAULT_DOCKER_IMAGE="sapk/cloud9"
DEFAULT_DOCKER_IMAGE_VERSION="latest"
DEFAULT_SERVICE_NAME="cloud9-service"

function usage() {
  echo "USAGE :"
  echo "deploy cloud9 in a docker instance on current host to get a web IDE for developement"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- parametres :"
  echo "L     create [--version=<version>] [--http=<port>] [--workspace=<path>] [--login=<string>] [--password=<string>] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start [--version=<version>] : start service"
  echo "L     stop [--version=<version>] : stop service"
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "o-- options :"
  echo "L     --http : cloud9 http port. By default : $DEFAULT_HTTP_PORT"
  echo "L     --workspace : Mounted workspace folder into cloud9. By default $DEFAULT_WORKSPACE directory is mounted, and file permissions used inside that folder are yours"
  echo "L     --login : optional login protection"
  echo "L     --password : optional password protection"
  echo "L     --version : cloud9 image version. By default : $DEFAULT_DOCKER_IMAGE_VERSION"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell'
"
OPTIONS="
HTTP='$DEFAULT_HTTP_PORT' 						'' 			'string'				s 			0			''		  Listening cloud9 http port.
WORKSPACE='$DEFAULT_WORKSPACE' 						'' 			'string'				s 			0			''		  Mounted workspace folder into cloud9
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Cloud9 image version.
LOGIN='$DEFAULT_LOGIN' 						'' 			'string'				s 			0			''		  optional login protection
PASSWORD='$DEFAULT_PASSWORD' 						'' 			'string'				s 			0			''		  optional password protection
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME

# test docker engine is installed in this system
$STELLA_API require "dockerd" "SYSTEM"


if [ "$ACTION" = "create" ]; then
    # delete previously stored container
    docker rm $SERVICE_NAME 2>/dev/null

    [ ! "$LOGIN" = "" ] && [ ! "$PASSWORD" = "" ] && with_auth=1
    
    # auth is a start option of cloud9
    # for other start option see here https://github.com/c9/core
    if [ "$with_auth" = "1" ]; then
        docker run -d \
            -p $HTTP:8181 \
            -u $(id -u):$(id -g) \
            --name "$SERVICE_NAME" \
            -v $WORKSPACE:/workspace \
            $DOCKER_URI \
            --auth "$LOGIN":"$PASSWORD"
    else
        docker run -d \
            -p $HTTP:8181 \
            -u $(id -u):$(id -g) \
            --name "$SERVICE_NAME" \
            -v $WORKSPACE:/workspace \
            $DOCKER_URI
    fi

fi

if [ "$ACTION" = "start" ]; then
    docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
    docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
    docker stats $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
    docker exec -it $SERVICE_NAME bash
fi
