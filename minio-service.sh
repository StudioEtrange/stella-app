#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="minio-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# SAMPLE of MINIO and REXRAY/S3FS
# install service
# ./minio-service create --accesskey=azerty123 --secretkey=azerty123 --storagepath=$HOME/miniostore

# install docker plugin rexray/s3fs
# docker plugin install rexray/s3fs --grant-all-permissions S3FS_OPTIONS="allow_other,use_path_request_style,nonempty,url=http://host:9000" S3FS_ENDPOINT="http://host:9000" S3FS_ACCESSKEY="azerty123" S3FS_SECRETKEY="azerty123"

# create & test volume
# docker volume create --driver rexray/s3fs testvol
# docker run -rm -v testvol:/data bash -c 'echo "test" > /data/test.txt'
# docker run -rm -v testvol:/data bash -c 'cat /data/test.txt'

# SERVICE INFO --------------------------------------
DEFAULT_PORT=9000
DEFAULT_SERVICE_NAME="minio-service"
DEFAULT_STORAGE_PATH="$STELLA_APP_WORK_ROOT/storage"

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE="minio/minio"
DEFAULT_DOCKER_IMAGE_VERSION="latest"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "minio service as a docker container for object storage server with S3 compatibility"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--accesskey=<key>] [--secretkey=<key>] [--storagepath=<path>] [--version=<version>] [--port=<port>] [--nopurge] [-- additional docker run options] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start : start service"
  echo "L     stop : stop service"
  echo "L     destroy [--version=<version>] [--storage] [--nopurge] : stop, delete service and all image files. At next create, everything will be forced to be downloaded."
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "L     logs : show logs"
  echo "L     purgedata : erase any internal data volume attached to the service and/or folder storing data on host"
  echo "o-- options :"
  echo "L     --port : minio listening port"
  echo "L     --version : minio image version"
  echo "L     --debug : active some debug trace"
  echo "L     --storage : will erase local folder used for storage"
  echo "L     --nopurge : do not erase any internal data volume attached to service while create/destroy"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy purgedata logs'  '1'
"
OPTIONS="
STORAGEPATH='$DEFAULT_STORAGE_PATH' 						'' 			'path'				s 			0			''		  Storage path.
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening port.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  portainer image version .
DEBUG=''            'd'    		''            		b     		0     		'1'           			Active some debug trace.
STORAGE=''            ''    		''            		b     		0     		'1'           		Delete storage path
NOPURGE=''            'n'    		''            		b     		0     		'1'           			Do not erase any internal data volume attached to service while create/destroy.
ACCESSKEY='' 						'' 			'key'				s 			0			''		  Storage access key.
SECRETKEY='' 						'' 			'key'				s 			0			''		  Storage secret key.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "EXTRA_ARG DOCKERARG" "$@"

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
SERVICE_DATA_NAME="$SERVICE_NAME"

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"


# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  # delete previously stored container
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  [ ! "${NOPURGE}" = "1" ] && __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

  mkdir -p "$STORAGEPATH"

  _OPT=
  [ ! "$ACCESSKEY" = "" ]  && _OPT="$_OPT -e MINIO_ACCESS_KEY=$ACCESSKEY"
  [ ! "$SECRETKEY" = "" ]  && _OPT="$_OPT -e MINIO_SECRET_KEY=$SECRETKEY"

  __log_run docker run -d \
              --name $SERVICE_NAME \
              --restart always \
              -p $PORT:9000 \
              -v $STORAGEPATH:/data \
              -v $SERVICE_DATA_NAME:/root/.minio \
              $_OPT $DOCKERARG $DOCKER_URI server /data
fi

if [ "$ACTION" = "destroy" ]; then
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  __log_run docker rmi $DOCKER_URI 2>/dev/null
  [ ! "${NOPURGE}" = "1" ] && __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

  [ "$STORAGE" = "1" ] && rm -Rf "$STORAGEPATH"
fi

if [ "$ACTION" = "start" ]; then
  __log_run docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
  __log_run docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
  __log_run docker ps -a | grep $SERVICE_NAME
  __log_run docker stats --no-stream $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
  __log_run docker exec -it $SERVICE_NAME sh
fi

if [ "$ACTION" = "logs" ]; then
  __log_run docker logs $SERVICE_NAME
fi

if [ "$ACTION" = "purgedata" ]; then
  __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
  rm -Rf "$STORAGEPATH"
fi

