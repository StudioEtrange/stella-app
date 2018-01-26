#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="cloud9-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://c9.io/
# https://hub.docker.com/r/sapk/cloud9/
# https://github.com/sapk/dockerfiles


DEFAULT_HTTP_PORT=20001
DEFAULT_WORKSPACE="$HOME"
DEFAULT_LOGIN=
DEFAULT_PASSWORD=

DEFAULT_DOCKER_IMAGE="sapk/cloud9"
DEFAULT_DOCKER_IMAGE_VERSION="alpine"
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
  echo "L     purge : purge service"
  echo "o-- options :"
  echo "L     --http : cloud9 http port"
  echo "L     --workspace : Mounted workspace folder into cloud9. File permissions used inside that folder are yours"
  echo "L     --login : optional login protection"
  echo "L     --password : optional password protection"
  echo "L     --version : cloud9 image version"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell purge'
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
SERVICE_DATA_NAME="vol-$SERVICE_NAME"

# test docker engine is installed in this system
$STELLA_API require "dockerd" "SYSTEM"

__local_bindfs_volume_create() {
	__volume_name="$1"
	__local_path="$2"

	docker volume create -d lebokus/bindfs -o sourcePath="$__local_path" -o map=$UID/0:@$UID/@0 --name "$__volume_name"
}


__require_bindfs_docker_plugin() {
  docker plugin inspect lebokus/bindfs 1>&2 2>/dev/null
  if [ "$?" = "1" ]; then
    echo "** Install docker volume plugin bindfs"
    docker plugin install lebokus/bindfs
  fi
}



if [ "$ACTION" = "create" ]; then
    # delete and stop previously stored container
    docker stop $SERVICE_NAME 2>/dev/null
    docker rm $SERVICE_NAME 2>/dev/null
    docker volume rm "$SERVICE_DATA_NAME" 2>/dev/null

    # create dedicated mount point through named volume with bindfs plugin
    if [ ! "$WORKSPACE" = "" ]; then
      __require_bindfs_docker_plugin
      __local_bindfs_volume_create "$SERVICE_DATA_NAME" "$WORKSPACE"
    fi

    with_auth=
    if [ ! "$LOGIN" = "" ]; then
    	if [ ! "$PASSWORD" = "" ]; then
    	   with_auth=1
    	fi
    fi

    # auth is a start option of cloud9
    # for other start option see here https://github.com/c9/core
    if [ "$with_auth" = "1" ]; then
        docker run -d \
            -p $HTTP:8181 \
            --name "$SERVICE_NAME" \
            --volume $SERVICE_DATA_NAME:/workspace \
            $DOCKER_URI \
            --auth "$LOGIN":"$PASSWORD"
    else
        # providing auth option with ":" as value, authorize exposing cloud9 to any IP without any login:password
        docker run -d \
            -p $HTTP:8181 \
            --name "$SERVICE_NAME" \
            --volume $SERVICE_DATA_NAME:/workspace \
            $DOCKER_URI \
            --auth :
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

if [ "$ACTION" = "purge" ]; then
  # remove cntainers
  docker stop $SERVICE_NAME 2>/dev/null
  docker rm $SERVICE_NAME 2>/dev/null
  # remove volume
  docker volume rm "$SERVICE_DATA_NAME" 2>/dev/null

  # remove image
  docker rmi $DOCKER_URI 2>/dev/null
fi
