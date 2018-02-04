#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="docker-registry-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# SERVICE INFO --------------------------------------
DEFAULT_SERVICE_NAME="docker-registry-service"
DEFAULT_REGISTRY_STORAGE_PATH="$STELLA_APP_WORK_ROOT/registry-storage"
DEFAULT_BACKEND_PORT="5000"
DEFAULT_FRONTEND_PORT="8080"
DEFAULT_REGISTRY_URI="http://${STELLA_HOST_DEFAULT_IP}:${DEFAULT_BACKEND_PORT}"


# DOCKER IMAGES INFO --------------------------------------
DEFAULT_COMPOSE_FILE_ROOT="$STELLA_APP_ROOT/docker-registry-pool"
DEFAULT_COMPOSE_FILE="$DEFAULT_COMPOSE_HOME/docker-compose.yml"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Deploy a docker registry and its frontend."
  echo "NOTE : can set a docker daemon with this registry as insecure registries."
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--registrypath=<path>] [--frontport=<port>] [--backport=<port>] : create & launch service (must be use once before starting/stopping service)/ Proxy and Proxy-gen are created together."
  echo "L     start : start service"
  echo "L     stop : stop service"
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running backend service"
  echo "L     purge [--storage] : purge service"
  echo "L     set [--registry=<schema://host:port>] : set local docker daemon to use this service as insecure registry. Meant to be run directly on a host of a docker daemon"
  echo "o-- options :"
  echo "L     --frontport : service registry frontend port"
  echo "L     --backport : service registry backend port"
  echo "L     --registry : uri of the backend registry to set on the local docker daemon"
  echo "L     --debug : active some debug trace"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell purge set'
"
OPTIONS="
REGISTRYPATH='$DEFAULT_REGISTRY_STORAGE_PATH' 						'' 			'path'				s 			0			''		  Storage path.
BACKPORT='$DEFAULT_BACKEND_PORT' 						'' 			'port'				s 			0			''		  Service registry backend port.
FRONTPORT='$DEFAULT_FRONTEND_PORT' 						'' 			'port'				s 			0			''		  Service registry frontend port.
REGISTRY='${DEFAULT_REGISTRY_URI}' 						'' 			'schema://host:port'				s 			0			''		  Service registry endpoint.
DEBUG=''            'd'    		''            		b     		0     		'1'           		Active some debug trace.
STORAGE=''            ''    		''            		b     		0     		'1'           		Delete storage path
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
	cat /etc/docker/daemon.json
  _tmp="$(mktemp)"
  jq "$@" /etc/docker/daemon.json > "$_tmp"
  mv -f "$_tmp" /etc/docker/daemon.json && rm -f "$_tmp"
}

__get_docker_daemon_options() {
    $STELLA_API require "jq" "jq" "STELLA_FEATURE"
    if [ -f "/etc/docker/daemon.json" ]; then
        jq "$@" /etc/docker/daemon.json
    fi
}


# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
SERVICE_NAME="$DEFAULT_SERVICE_NAME"
COMPOSE_FILE_ROOT="$DEFAULT_COMPOSE_FILE_ROOT"
COMPOSE_FILE="$DEFAULT_COMPOSE_FILE"
DOCKER_COMPOSE_OPT="--project-name $SERVICE_NAME"
[ "$DEBUG" = "1" ] && DOCKER_COMPOSE_OPT="$DOCKER_COMPOSE_OPT --verbose"

[ "$REGISTRYPATH" = "" ] && REGISTRY_STORAGE_PATH="$DEFAULT_REGISTRY_STORAGE_PATH" || REGISTRY_STORAGE_PATH="$REGISTRYPATH"
export REGISTRY_STORAGE_PATH="$REGISTRY_STORAGE_PATH"
export REGISTRY_FRONTEND_PORT="$FRONTPORT"
export REGISTRY_BACKEND_PORT="$BACKPORT"

# info used to setup docker daemon
$STELLA_API uri_parse "$REGISTRY"
REGISTRY_SHORT="$__stella_uri_address"
REGISTRY_HOST="$__stella_uri_host"
REGISTRY_PORT="$__stella_uri_port"
[ "$REGISTRY_PORT" = "" ] && REGISTRY_PORT=$DEFAULT_BACKEND_PORT


$STELLA_API require "docker" "docker" "SYSTEM"
$STELLA_API require "docker-compose" "docker-compose" "STELLA_FEATURE"


# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
  mkdir -p "$REGISTRY_STORAGE_PATH"
  cd "$DEFAULT_COMPOSE_FILE_ROOT"
  #__log_run docker-compose $DOCKER_COMPOSE_OPT down --volumes
  __log_run docker-compose $DOCKER_COMPOSE_OPT up -d
fi

if [ "$ACTION" = "start" ]; then
  mkdir -p "$REGISTRY_STORAGE_PATH"
  cd "$DEFAULT_COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT start
fi

if [ "$ACTION" = "stop" ]; then
  cd "$DEFAULT_COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT stop
fi

if [ "$ACTION" = "purge" ]; then
  cd "$DEFAULT_COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT down --rmi all --volumes
  [ "$STORAGE" = "1" ] && rm -Rf "$REGISTRY_STORAGE_PATH"
fi

if [ "$ACTION" = "status" ]; then
  cd "$DEFAULT_COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT ps
fi

if [ "$ACTION" = "shell" ]; then
  cd "$DEFAULT_COMPOSE_FILE_ROOT"
  __log_run docker-compose $DOCKER_COMPOSE_OPT exec backend sh
fi


if [ "$ACTION" = "set" ]; then
  echo " ** Run this command only on a host of a docker daemon"
  __test_sudo
  echo " ** Setting $REGISTRY_SHORT an authorizd insecure registry"
  __set_docker_daemon_options '."insecure-registries" = [ "'$REGISTRY_SHORT'" ]'
  __get_docker_daemon_options '."insecure-registries"'
  echo " ** Please restart docker daemon"
fi
