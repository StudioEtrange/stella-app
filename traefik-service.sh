#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="traefik-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://github.com/containous/traefik
# https://store.docker.com/images/traefik
# https://github.com/sapk/dockerfiles

# SERVICE INFO --------------------------------------
DEFAULT_HTTP_PORT=80
DEFAULT_HTTP_ADMIN_PORT=8080
DEFAULT_CONF="$STELLA_APP_ROOT/traefik-pool/traefik.toml"
DEFAULT_SERVICE_NAME="traefik-service"

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE="traefik"
DEFAULT_DOCKER_IMAGE_VERSION="alpine"


# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Traefik service as docker instance on current host to get a modern reverse proxy"
  echo "NOTE : require docker on your system"
  echo "NOTE : it can provide default configuration for listening to docker backend (use '--docker' option on create)"
  echo "----------------"
  echo "o-- command :"
  echo "L     create [--version=<version>] [--http=<port>] [--httpadmin=<port>] [--conf=<path>] [--docker] [-- <options>] : create & launch service (must be use once before starting/stopping service)"
  echo "L     start [--version=<version>] : start service"
  echo "L     stop [--version=<version>] : stop service"
  echo "L     destroy : destroy service"
  echo "L     status : give service status info"
  echo "L     shell : launch a shell inside running service"
  echo "L     logs : show logs"
  echo "o-- options :"
  echo "L     --http : traefik http reverse proxy port (entry port)"
  echo "L     --httpadmin : traefik http admin port"
  echo "L     --conf : path to a conf file (ex: traefik.toml)"
  echo "L     --version : traefik image version"
  echo "L     --docker : will compute some default option to use docker as backend"
  echo "L     --debug : active some debug trace"
  echo "L     -- : use this with create command, allow to pass options directly to traefik daemon"

  echo "SAMPLES :"
  echo "----------------"
  echo "sample with docker backend"
  echo "traefik route trafic from http://host:80/blog to ghost blog engine container on port 2368. Here, ghost container do not expose port outside"
  echo "traefik-service.sh create -d --docker"
  echo "docker run -d --label traefik.backend=\"blog\" --label traefik.frontend.rule=\"Host:localhost\" --label traefik.port=2368 ghost"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a			create start stop status shell destroy logs'  '1'
"
OPTIONS="
HTTP='$DEFAULT_HTTP_PORT' 						'' 			'string'				s 			0			''		  Traefik http port (entry port).
HTTPADMIN='$DEFAULT_HTTP_ADMIN_PORT' 						'' 			'string'				s 			0			''		  Traefik http admin port.
CONF='$DEFAULT_CONF' 						'' 			'string'				s 			0			''		  Configuration file (ex : /path/traefik.toml).
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Traefik image version.
DOCKER=''            ''    		''            		b     		0     		'1'           			Active some debug trace.
DEBUG=''            'd'    		''            		b     		0     		'1'           			Will compute some default option to use docker as backend.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "EXTRA_ARG DOCKERARG" "$@"

# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"

# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then
    # delete and stop previously stored container and volume
    __log_run docker stop $SERVICE_NAME 2>/dev/null
    __log_run docker rm $SERVICE_NAME 2>/dev/null

    DOCKER_BACKEND_OPTIONS=""
    if [ "$DOCKER" == "1" ]; then
      DOCKER_BACKEND_OPTIONS="--docker --docker.watch"

      # Determine all options used to connect to the docker daemon (Use environment var over default one)

      # Determine the endpoint to see if we have to mount the socket file
      [ ! "$DOCKER_HOST" == "" ] && DOCKER_ENDPOINT="$DOCKER_HOST" || DOCKER_ENDPOINT="unix:///var/run/docker.sock"
      # NOTE : protocol http+unix:// should be considered a socket connexion, as unix://
      DOCKER_ENDPOINT="${DOCKER_ENDPOINT/http+unix/unix}"
      $STELLA_API uri_parse "$DOCKER_ENDPOINT"

      DOCKER_SOCKET_MOUNT=""
      case "$__stella_uri_schema" in
        unix|"")
            DOCKER_SOCKET_MOUNT="-v $__stella_uri_path:$__stella_uri_path"
          ;;
        *)
          ;;
      esac
      DOCKER_BACKEND_OPTIONS="$DOCKER_BACKEND_OPTIONS --docker.endpoint=$DOCKER_ENDPOINT"

      DOCKER_CERT_MOUNT=""
      if [ ! "$DOCKER_CERT_PATH" = "" ]; then
        DOCKER_BACKEND_OPTIONS="$DOCKER_BACKEND_OPTIONS \
              --docker.tls --docker.tls.ca=/ssl/ca.pem --docker.tls.cert=/ssl/cert.pem --docker.tls.key=/ssl/key.pem"
        DOCKER_CERT_MOUNT="-v $DOCKER_CERT_PATH:/ssl"
      fi
      [ ! "$DOCKER_TLS_VERIFY" = "" ] && DOCKER_BACKEND_OPTIONS="$DOCKER_BACKEND_OPTIONS --docker.tls.insecureSkipVerify"


    fi

    __log_run docker run -d \
        --name $SERVICE_NAME \
        --restart always \
        -p $HTTP:80 \
        -p $HTTPADMIN:8080 \
        -v $CONF:/etc/traefik/traefik.toml \
        $DOCKER_SOCKET_MOUNT $DOCKER_CERT_MOUNT \
        $DOCKER_URI "$DOCKER_BACKEND_OPTIONS" $DOCKERARG
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

if [ "$ACTION" = "destroy" ]; then
  # remove cntainers
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  # remove image
  __log_run docker rmi $DOCKER_URI 2>/dev/null
fi

if [ "$ACTION" = "logs" ]; then
  __log_run docker logs $SERVICE_NAME
fi
