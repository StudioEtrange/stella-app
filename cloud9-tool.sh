#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="cloud9-tool.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://c9.io/
# https://hub.docker.com/r/sapk/cloud9/
# https://github.com/sapk/dockerfiles
# https://github.com/StudioEtrange/dockerfiles

# NOTE : cloud9 do not use docker 'restart always' option, cause it is an IDE on demand, a tool, not really a service
# TODO : add usefull tools not present in default image (ssh,...)

# default http port is empty, so docker will choose one free
DEFAULT_HTTP_PORT=
DEFAULT_WORKSPACE="$HOME"
DEFAULT_LOGIN=
DEFAULT_PASSWORD=

DEFAULT_DOCKER_IMAGE="sapk/cloud9"
DEFAULT_DOCKER_IMAGE_VERSION="alpine"
DEFAULT_SERVICE_NAME="cloud9-tool"

function usage() {
  echo "USAGE :"
  echo "cloud9 IDE as a docker container on current host to get a web IDE for developement"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--version=<version>] [--http=<port>] [--workspace=<path>] [--login=<string>] [--password=<string>] : create & launch tool (must be use once before starting/stopping tool)"
  echo "L     start [--version=<version>] : start tool"
  echo "L     stop [--version=<version>] : stop tool"
  echo "L     status : give resource status"
  echo "L     info : give service information"
  echo "L     shell : launch a shell inside running tool"
  echo "L     destroy : destroy tool"
  echo "o-- options :"
  echo "L     --http : cloud9 http port"
  echo "L     --workspace : Mounted workspace folder into cloud9. File permissions used inside that folder are yours"
  echo "L     --login : optional login protection"
  echo "L     --password : optional password protection"
  echo "L     --version : cloud9 image version"
  echo "L     --debug : active some debug trace"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy info'
"
OPTIONS="
HTTP='$DEFAULT_HTTP_PORT' 						'' 			'string'				s 			0			''		  Listening cloud9 http port.
WORKSPACE='$DEFAULT_WORKSPACE' 						'' 			'string'				s 			0			''		  Mounted workspace folder into cloud9.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Cloud9 image version.
LOGIN='$DEFAULT_LOGIN' 						'' 			'string'				s 			0			''		  optional login protection.
PASSWORD='$DEFAULT_PASSWORD' 						'' 			'string'				s 			0			''		  optional password protection.
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"


DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME
SERVICE_DATA_NAME="vol-$SERVICE_NAME"

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"

__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

__local_bindfs_volume_create() {
	__volume_name="$1"
	__local_path="$2"
  # user uid inside container
  __uid="$3"
  # group gid inside container
  __gid="$4"
  [ "$__uid" = "" ] && __uid="0"
  [ "$__gid" = "" ] && __gid="0"

	__log_run docker volume create -d lebokus/bindfs -o sourcePath="$__local_path" -o map=$UID/$__uid:@$UID/@$__gid --name "$__volume_name" 2>/dev/null
}

__require_bindfs_docker_plugin() {
  __log_run docker plugin inspect lebokus/bindfs 1>/dev/null 2>&1
  if [ "$?" = "1" ]; then
    echo "** Install docker volume plugin bindfs"
    __log_run docker plugin install lebokus/bindfs
  fi
}


__get_service_endpoint() {
  __internal_service_port="$1"
  __port="$(docker inspect --format='{{(index (index .NetworkSettings.Ports "$__internal_service_port/tcp") 0).HostPort}}' $SERVICE_NAME)"
  echo "http://$(hostname):$__port"
}

if [ "$ACTION" = "create" ]; then
    # delete and stop previously stored container and volume
    __log_run docker stop $SERVICE_NAME 2>/dev/null
    __log_run docker rm $SERVICE_NAME 2>/dev/null
    __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

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
        __log_run docker run -d \
            -p $HTTP:8181 \
            --name "$SERVICE_NAME" \
            --volume $SERVICE_DATA_NAME:/workspace \
            $DOCKER_URI \
            --auth "$LOGIN":"$PASSWORD"
    else
        # providing auth option with ":" as value, authorize exposing cloud9 to any IP without any login:password
        __log_run docker run -d \
            -p $HTTP:8181 \
            --name "$SERVICE_NAME" \
            --volume $SERVICE_DATA_NAME:/workspace \
            $DOCKER_URI \
            --auth :
    fi

    __get_service_endpoint "8181"
fi

if [ "$ACTION" = "start" ]; then
    __log_run docker start $SERVICE_NAME
    __get_service_endpoint "8181"
fi

if [ "$ACTION" = "stop" ]; then
    __log_run docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
    __log_run docker stats $SERVICE_NAME
fi

if [ "$ACTION" = "info" ]; then
    __get_service_endpoint "8181"
fi

if [ "$ACTION" = "shell" ]; then
    __log_run docker exec -it $SERVICE_NAME bash
fi

if [ "$ACTION" = "destroy" ]; then
  # remove cntainers
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  # remove volume
  __log_run docker volume rm "$SERVICE_DATA_NAME" 2>/dev/null
  # remove image
  __log_run docker rmi $DOCKER_URI 2>/dev/null
fi
