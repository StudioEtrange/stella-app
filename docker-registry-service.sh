#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="docker-registry-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# NOTE
#     'frontend' is a web UI
#     'backend' is the docker registry
#     frontend and backend are meant to be run on the same node

# SERVICE INFO --------------------------------------
DEFAULT_SERVICE_NAME="docker-registry-service"
DEFAULT_REGISTRY_STORAGE_PATH="$STELLA_APP_WORK_ROOT/registry-storage"
DEFAULT_BACKEND_PORT="5000"
DEFAULT_FRONTEND_PORT="8080"
DEFAULT_REGISTRY_URI="http://${STELLA_HOST_DEFAULT_IP}:${DEFAULT_BACKEND_PORT}"


# DOCKER IMAGES INFO --------------------------------------
DEFAULT_COMPOSE_FILE="$STELLA_APP_ROOT/docker-registry-pool/docker-compose.yml"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Deploy a docker registry and its frontend."
  echo "NOTE : can set a docker daemon with this registry as insecure registries."
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--registrypath=<path>] [--frontport=<port>] [--backport=<port>] [--name=<name>] [--compose=<path>]: create & launch service (must be use once before starting/stopping service)."
  echo "L     start [--name=<name>] [--compose=<path>] : start service"
  echo "L     stop [--name=<name>] [--compose=<path>] : stop service"
  echo "L     status [--name=<name>] [--compose=<path>] : give service status info"
  echo "L     shell [--name=<name>] [--compose=<path>] : launch a shell inside running backend service"
  echo "L     destroy [--storage] [--name=<name>] [--compose=<path>] : destroy service"
  echo "L     insecure|secure [--registry=<schema://host:port>] : set a local docker daemon to use the registry as an insecure registry. OR remove this registry from insecure registry list."
  echo "o-- options :"
  echo "L     --frontport : web ui frontend port"
  echo "L     --backport : registry port"
  echo "L     --registry : uri of the backend registry to set on the local docker daemon"
  echo "L     --debug : active some debug trace"
  echo "L     --name : registry name"
  echo "L     --compose : compose file"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell destroy insecure secure' '1'	
"
OPTIONS="
REGISTRYPATH='${DEFAULT_REGISTRY_STORAGE_PATH}' 						'' 			'path'				s 			0			''		  Storage path.
BACKPORT='${DEFAULT_BACKEND_PORT}' 						'' 			'port'				s 			0			''		  Service registry backend port.
FRONTPORT='${DEFAULT_FRONTEND_PORT}' 						'' 			'port'				s 			0			''		  Service registry frontend port.
REGISTRY='${DEFAULT_REGISTRY_URI}' 						'' 			'schema://host:port'				s 			0			''		  Service registry endpoint.
DEBUG=''            'd'    		''            		b     		0     		'1'           		Active some debug trace.
STORAGE=''            ''    		''            		b     		0     		'1'           		Delete storage path
NAME='' 						'n' 			'name'				s 			0			''		  A name.
COMPOSE='${DEFAULT_COMPOSE_FILE}' 						'' 			'file'				s 			0			''		  Path to compose file.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"

# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

__test_sudo() {
	if [ $(id -u) -ne 0 ]; then
		echo "** Please run as root or sudo"
		exit 1
	fi
}

__set_docker_daemon_options() {
  $STELLA_API require "jq" "jq" "STELLA_FEATURE"

  if [ ! -f "/etc/docker/daemon.json" ]; then
    	mkdir -p "/etc/docker"
    	echo '{}' > /etc/docker/daemon.json
  fi
	if [ ! -s "/etc/docker/daemon.json" ]; then
			echo '{}' > /etc/docker/daemon.json
	fi
  _tmp="$(mktemp)"
  jq "$@" /etc/docker/daemon.json > "${_tmp}"
  cat "${_tmp}" > /etc/docker/daemon.json
  rm -f "${_tmp}"
  #mv -f "$_tmp" /etc/docker/daemon.json && rm -f "$_tmp"
}

__get_docker_daemon_options() {
    $STELLA_API require "jq" "jq" "STELLA_FEATURE"
    if [ -f "/etc/docker/daemon.json" ]; then
        jq "$@" /etc/docker/daemon.json
    fi
}


__registry_name_validate() {
	valid='a-zA-Z_'
	if [[ ! "${1}" =~ [^$valid] ]]; then
		# valide
		echo "1"
	else
		echo "0"
	fi
}


# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
if [ ! "$NAME" = "" ]; then
  if [ "$(__registry_name_validate ${NAME})" = "0" ]; then
    echo "** ERROR : invalid registry name. (Valid characters : a-zA-Z_)"
    exit 1
  fi
  DEFAULT_REGISTRY_STORAGE_PATH="${DEFAULT_REGISTRY_STORAGE_PATH}_${NAME}"
  DEFAULT_SERVICE_NAME="${DEFAULT_SERVICE_NAME}_${NAME}"
fi

SERVICE_NAME="$DEFAULT_SERVICE_NAME"

$STELLA_API require "docker" "docker" "SYSTEM"
case $ACTION in
  create|start|stop|destroy|status|shell )
    $STELLA_API require "docker-compose" "docker-compose" "STELLA_FEATURE"
    COMPOSE_FILE="${COMPOSE}"
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


[ "$REGISTRYPATH" = "" ] && REGISTRY_STORAGE_PATH="$DEFAULT_REGISTRY_STORAGE_PATH" || REGISTRY_STORAGE_PATH="$REGISTRYPATH"
export REGISTRY_STORAGE_PATH="$REGISTRY_STORAGE_PATH"
export REGISTRY_FRONTEND_PORT="$FRONTPORT"
export REGISTRY_BACKEND_PORT="$BACKPORT"

# info used to setup docker daemon
$STELLA_API uri_parse "$REGISTRY"
REGISTRY_SHORT="$__stella_uri_address"
REGISTRY_HOST="$__stella_uri_host"
REGISTRY_PORT="$__stella_uri_port"






# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  mkdir -p "$REGISTRY_STORAGE_PATH"
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT down --volumes
  __log_run docker-compose $DOCKER_COMPOSE_OPT up -d
fi

if [ "$ACTION" = "start" ]; then
  mkdir -p "$REGISTRY_STORAGE_PATH"
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
  [ "$STORAGE" = "1" ] && rm -Rf "$REGISTRY_STORAGE_PATH"
fi

if [ "$ACTION" = "status" ]; then
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT ps
fi

if [ "$ACTION" = "shell" ]; then
  cd "$COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT exec backend sh
fi


if [ "$ACTION" = "insecure" ]; then
  __test_sudo
  echo " ** Setting $REGISTRY_SHORT an authorized insecure registry"
  __set_docker_daemon_options '."insecure-registries" += [ "'$REGISTRY_SHORT'" ]'
  __get_docker_daemon_options ''
  echo " ** Please restart docker daemon"
fi

if [ "$ACTION" = "secure" ]; then
  __test_sudo
  echo " ** Setting $REGISTRY_SHORT an authorized insecure registry"
  __set_docker_daemon_options '."insecure-registries" -= [ "'$REGISTRY_SHORT'" ]'
  __get_docker_daemon_options ''
  echo " ** Please restart docker daemon"
fi
