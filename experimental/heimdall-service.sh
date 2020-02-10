#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="heimdall-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# NOTE
#     'frontend' is heimdall UI
#     'backend' is an auto generated API over sqlite DB of heimdall -- http://backend is API endpoint http://backend/admin is HTTP web interface for API
#     frontend and backend are meant to be run on the same host

# SERVICE INFO --------------------------------------
DEFAULT_SERVICE_NAME="heimdall-service"
DEFAULT_HEIMDALL_DATA_PATH="$STELLA_APP_WORK_ROOT/heimdall-data"
DEFAULT_BACKEND_PORT="10081"
DEFAULT_FRONTEND_PORT="10080"


# DOCKER IMAGES INFO --------------------------------------
DEFAULT_COMPOSE_FILE="$STELLA_APP_ROOT/heimdall-service-pool/docker-compose.yml"
export DEFAULT_DOCKER_IMAGE_heimdall="linuxserver/heimdall"
export DEFAULT_DOCKER_IMAGE_VERSION_heimdall="2.2.2-ls73"
export DEFAULT_DOCKER_IMAGE_sandman2="jeffknupp/sandman2"
export DEFAULT_DOCKER_IMAGE_VERSION_sandman2="latest"


# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Deploy heimdall with docker and an api over its database"
  echo "       frontend is heimdall itslef, backend is an HTTP API over its database"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--frontport=<port>] [--backport=<port>] [--datapath=<path>] [--compose=<path>] [--frontversion=<version>] [--backversion=<version>] : create & launch service (must be use once before starting/stopping service)."
  echo "L     start [--compose=<path>] : start service"
  echo "L     stop [--compose=<path>] : stop service"
  echo "L     status [--compose=<path>] : give service status info"
  echo "L     shell [--compose=<path>] : launch a shell inside running backend service"
  echo "L     destroy [--data] [--compose=<path>] : destroy service"
  echo "L     purgedata : erase any internal data volume attached to the service and/or folder storing data on host"
  echo "L     logs [--compose=<path>] : show backend logs"
  echo "o-- options :"
  echo "L     --frontport : web ui frontend port"
  echo "L     --backport : registry port"
  echo "L     --debug : active some debug trace"
  echo "L     --compose : compose file"
  echo "L     --frontversion : heimdall docker image version"
  echo "L     --backversion : sandman2 docker image version"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy insecure secure logs purgedata' '1'
"
OPTIONS="
DATAPATH='${DEFAULT_HEIMDALL_DATA_PATH}' 						'' 			'path'				s 			0			''		  Storage path.
BACKPORT='${DEFAULT_BACKEND_PORT}' 						'' 			'port'				s 			0			''		  Service registry backend port.
FRONTPORT='${DEFAULT_FRONTEND_PORT}' 						'' 			'port'				s 			0			''		  Service registry frontend port.
DEBUG=''            'd'    		''            		b     		0     		'1'           		Active some debug trace.
DATA=''            ''    		''            		b     		0     		'1'           		Delete data folder
COMPOSE='${DEFAULT_COMPOSE_FILE}' 						'' 			'file'				s 			0			''		  Path to compose file.
FRONTVERSION='${DEFAULT_DOCKER_IMAGE_VERSION_heimdall}' 						'' 			'file'				s 			0			''		  heimdall docker image version.
BACKVERSION='${DEFAULT_DOCKER_IMAGE_VERSION_sandman2}' 						'' 			'file'				s 			0			''		  sandman2 (api over heimdall aka backend) docker image version.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "" "$@"

# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}







# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
SERVICE_NAME="$DEFAULT_SERVICE_NAME"

$STELLA_API require "docker" "docker" "SYSTEM"

case $ACTION in
  create|start|stop|destroy|status|shell|logs )
    $STELLA_API get_feature "docker-compose" "docker-compose" "STELLA_FEATURE"
    COMPOSE_FILE="$($STELLA_API rel_to_abs_path ${COMPOSE} ${_CURRENT_RUNNING_DIR})"
    if [ ! -f "${COMPOSE_FILE}" ]; then
      echo "** ERROR : Compose file ${COMPOSE_FILE} do not exist"
      exit 1
    fi
    COMPOSE_FILE_ROOT="$(dirname ${COMPOSE})"
    DOCKER_COMPOSE_OPT="--project-name ${SERVICE_NAME} -f ${COMPOSE_FILE}"
    ;;
esac



# NOTE : to much verbose
#[ "$DEBUG" = "1" ] && DOCKER_COMPOSE_OPT="$DOCKER_COMPOSE_OPT --verbose"



[ "$DATAPATH" = "" ] && HEIMDALL_DATA_PATH="$DEFAULT_HEIMDALL_DATA_PATH" || HEIMDALL_DATA_PATH="$DATAPATH"
export HEIMDALL_DATA_PATH="$HEIMDALL_DATA_PATH"


export HEIMDALL_FRONTEND_PORT="$FRONTPORT"
export HEIMDALL_BACKEND_PORT="$BACKPORT"
export HEIMDALL_VERSION="$FRONTVERSION"
export SANDMAN2_VERSION="$BACKVERSION"
export HEIMDALL_USER_ID="$(id -u)"
export HEIMDALL_GROUP_ID="$(id -g)"





# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  mkdir -p "$HEIMDALL_DATA_PATH"
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT down --volumes
  __log_run docker-compose $DOCKER_COMPOSE_OPT up -d
fi

if [ "$ACTION" = "start" ]; then
  mkdir -p "$HEIMDALL_DATA_PATH"
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT start
fi

if [ "$ACTION" = "stop" ]; then
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT stop
fi

if [ "$ACTION" = "destroy" ]; then
  cd "$COMPOSE_FILE_ROOT"
  # NOTE we cannot remove image with rmi because when using --name argument there might be several other instance using theses imagess
  #__log_run docker-compose $DOCKER_COMPOSE_OPT down --rmi all --volumes
  __log_run docker-compose $DOCKER_COMPOSE_OPT down --volumes
  [ "$DATA" = "1" ] && rm -Rf "$HEIMDALL_DATA_PATH"
fi


if [ "$ACTION" = "purgedata" ]; then
  rm -Rf "$HEIMDALL_DATA_PATH"
fi

if [ "$ACTION" = "status" ]; then
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT ps
fi

if [ "$ACTION" = "shell" ]; then
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT exec backend sh
fi

if [ "$ACTION" = "logs" ]; then
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT logs backend
fi

