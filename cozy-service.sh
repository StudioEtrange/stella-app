#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="cozy-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://cozy.io
# https://docs.cozy.io/en/host/install/install-on-docker.html
# https://docs.cozy.io/en/host/install/install-step-by-step.html
# https://github.com/cozy-labs/cozy-docker

# TODO nginx reverse proxy ? step 9 : https://docs.cozy.io/en/host/install/install-step-by-step.html

DEFAULT_HTTP_PORT=9000
DEFAULT_HTTPS_PORT=9001
# NOTE : we build our own image instead using cozy/full --
# "It is highly recommended to build the image locally if you want to run Cozy in a production environment
# This way, the security tokens will be reset, and the SSL certificate will be renewed.
DEFAULT_DOCKER_IMAGE="studioetrange/cozy-service"
DEFAULT_DOCKER_IMAGE_VERSION="latest"
DEFAULT_SERVICE_NAME="cozy-service"

function usage() {
  echo "USAGE :"
  echo "deploy cozy in a docker instance"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- parametres :"
  echo "L     create [--http=<port>] [--https=<port>] : create & launch cozy service (must be use once before starting/stopping service)"
  echo "L     start : start netdata service"
  echo "L     stop : stop netdata service"
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "L     purge : purge service"
  echo "o-- options :"
  echo "L     --http : cozy http port"
  echo "L     --https : cozy https port"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell purge'
"
OPTIONS="
HTTP='$DEFAULT_HTTP_PORT' 						'' 			'string'				s 			0			''		  Listening http port.
HTTPS='$DEFAULT_HTTPS_PORT' 						'' 			'string'				s 			0			''		  Listening https port.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"

DOCKER_IMAGE_VERSION=$DEFAULT_DOCKER_IMAGE_VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME
SERVICE_DATA_NAME="$SERVICE_NAME"-data
SERVICE_DATA_ROOT=$STELLA_APP_WORK_ROOT/$SERVICE_DATA_NAME


# test docker engine is installed in this system
$STELLA_API require "dockerd" "SYSTEM"


# https://github.com/titpetric/netdata
if [ "$ACTION" = "create" ]; then

  # delete previously stored container
  docker rm $SERVICE_NAME 2>/dev/null

  # create a data volume container
  mkdir -p $SERVICE_DATA_ROOT
  mkdir -p $SERVICE_DATA_ROOT/couchdb
  mkdir -p $SERVICE_DATA_ROOT/etc/cosy
  mkdir -p $SERVICE_DATA_ROOT/usr/local/cosy
  mkdir -p $SERVICE_DATA_ROOT/usr/local/var/cozy
  docker create --name $SERVICE_DATA_NAME \
                -v $SERVICE_DATA_ROOT/couchdb:/var/lib/couchdb \
                -v $SERVICE_DATA_ROOT/etc/cosy:/etc/cozy \
                -v $SERVICE_DATA_ROOT/usr/local/cosy:/usr/local/cozy \
                -v $SERVICE_DATA_ROOT/usr/local/var/cozy:/usr/local/var/cozy \
                busybox true

  docker build --rm -t $DOCKER_URI github.com/cozy-labs/cozy-docker

  docker run -d \
              -p $DEFAULT_HTTP_PORT:80 \
              -p $DEFAULT_HTTPS_PORT:443 \
              --name "$SERVICE_NAME" \
              --volumes-from $SERVICE_DATA_NAME \
              $DOCKER_URI


# VOLUME ["/var/lib/couchdb", "/etc/cozy", "/usr/local/cozy", "/usr/local/var/cozy/"]

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

if [ "$ACTION" = "shell" ]; then
  docker exec -it $SERVICE_NAME bash
fi

if [ "$ACTION" = "purge" ]; then
  # remove cntainers
  docker rm $SERVICE_NAME
  docker rm $SERVICE_DATA_NAME
  # remove image
  docker rmi $DEFAULT_DOCKER_IMAGE
fi
