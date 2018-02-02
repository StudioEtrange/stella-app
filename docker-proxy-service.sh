#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="consul-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include



# NOTE :
# Use order :
# 1 deploy registrator
# 2 deploy proxy
# 3 deploy proxy-gen

# Example with docker-machine
# docker-machine create test
# eval $(docker-machine env test)
# ./consul-service.sh create server 1 -d --http=8500 --ip=$(docker-machine ip $DOCKER_MACHINE_NAME)
# docker logs consul-service-server-1
# ./docker-proxy-service.sh create registrator -d --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --serviceip=$(docker-machine ip $DOCKER_MACHINE_NAME)
# docker logs docker-proxy-service-registrator

# hello world example
# ./docker-proxy-service.sh create proxy -d --proxy=80 --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --template=$(pwd)/docker-proxy-pool/nginx-hello-world.ctmpl
# docker logs docker-proxy-service-proxygen
# docker run --name hello-world-1 -l SERVICE_NAME=hello-world -d -p 80 tutum/hello-world
# docker run -it --volumes-from docker-proxy-service-proxy busybox more /etc/nginx/conf.d/default.conf
# see http://$DOCKER_MACHINE_NAME)
# docker stop hello-world-1 && docker rm hello-world-1


# redirect service example
# ./docker-proxy-service.sh create proxy -d --proxy=80 --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --template=$(pwd)/docker-proxy-pool/nginx-redirect.ctmpl
# docker run --name ghost -l SERVICE_NAME=ghost -l SERVICE_TAGS=redirect -d -P ghost
# docker logs docker-proxy-service-proxygen
# docker run -it --volumes-from docker-proxy-service-proxy busybox more /etc/nginx/conf.d/default.conf
# see http://$DOCKER_MACHINE_NAME)/ghost
# docker stop ghost && docker rm ghost


# SERVICE INFO --------------------------------------
DEFAULT_SERVICE_NAME="docker-proxy-service"
DEFAULT_CONSUL_URI=localhost:8500
DEFAULT_PROXY_PORT=80
#DEFAULT_TEMPLATE="$STELLA_APP_ROOT/docker-proxy-pool/nginx.ctmpl"
DEFAULT_TEMPLATE=

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE_registrator="gliderlabs/registrator"
DEFAULT_DOCKER_IMAGE_VERSION_registrator="latest"
DEFAULT_DOCKER_IMAGE_proxy="nginx"
DEFAULT_DOCKER_IMAGE_VERSION_proxy="alpine"
DEFAULT_DOCKER_IMAGE_proxygen="studioetrange/docker-consul-template"
DEFAULT_DOCKER_IMAGE_VERSION_proxygen="0.19.4"

# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Provide an auto-configured reverse proxy for deployed docker."
  echo "NOTE : require docker on your system"
  echo "NOTE : It use registrator, nginx, and consul-template. It needs consul."
  echo "----------------"
  echo "o-- command :"
  echo "L     create <registrator|proxy> [--version=<version>] [--consul=<uri>] [--proxy=<port>] [--serviceip=<ip>] [--template=<path>] : create & launch service (must be use once before starting/stopping service)/ Proxy and Proxy-gen are created together."
  echo "L     start <registrator|proxy|proxygen> : start service"
  echo "L     stop <registrator|proxy|proxygen> : stop service"
  echo "L     status <registrator|proxy|proxygen> : give service status info"
  echo "L     shell <registrator|proxy|proxygen> : launch a shell inside running service"
  echo "L     purge <registrator|proxy> [--version=<version>] : purge service"
  echo "o-- options :"
  echo "L     --consul : consul http api port"
  echo "L     --proxy : reverse proxy port"
  echo "L     --serviceip : IP on which detected services by registrator are exposed"
  echo "L     --template : path to a template file for proxy-gen (ex: nginx.ctml)"
  echo "L     --version : consul image version"
  echo "L     --debug : active some debug trace"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'create start stop status shell purge'
TARGET=											'' 			a				'registrator proxy proxygen'
"
OPTIONS="
CONSUL='$DEFAULT_CONSUL_URI' 						'' 			'string'				s 			0			''		  Consul URI.
PROXY='$DEFAULT_PROXY_PORT' 						'' 			'string'				s 			0			''		  Reverse proxy port.
SERVICEIP='$DEFAULT_HOST_IP' 						'' 			'string'				s 			0			''		  IP on which detected services by registrator are exposed.
VERSION='' 			'v' 			'string'				s 			0			''		  Docker image version.
TEMPLATE='$DEFAULT_TEMPLATE' 						'' 			'string'				s 			0			''		  Template file for proxy-gen (ex : /path/nginx.ctmpl).
DEBUG=''            'd'    		''            		b     		0     		'1'           		Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "APPARG" "$@"

# FUNCTIONS --------------------------------------
__compute_var() {
  __subservice="$1"
  if [ ! "$__subservice" = "" ]; then
    _tmp="DEFAULT_DOCKER_IMAGE_${__subservice}"
    DEFAULT_DOCKER_IMAGE="${!_tmp}"
    _tmp="DEFAULT_DOCKER_IMAGE_VERSION_${__subservice}"
    DEFAULT_DOCKER_IMAGE_VERSION="${!_tmp}"
  fi

  [ "$VERSION" = "" ] && DOCKER_IMAGE_VERSION=$DEFAULT_DOCKER_IMAGE_VERSION || DOCKER_IMAGE_VERSION=$VERSION
  DOCKER_URI=$DEFAULT_DOCKER_IMAGE
  [ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
  SERVICE_NAME=$DEFAULT_SERVICE_NAME
  [ ! "$__subservice" = "" ] && SERVICE_NAME="${SERVICE_NAME}-${__subservice}"
  SERVICE_DATA_NAME="$SERVICE_NAME"
}

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"


__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}



if [ "$ACTION" = "create" ]; then


    case $TARGET in
      proxygen)
          echo "** ERROR : use proxy instead. proxy & proxygen are created together"
          exit 1
        ;;

      registrator )
          __compute_var "$TARGET"
          $STELLA_API uri_parse "$CONSUL"

          __log_run docker run -d \
            --name=$SERVICE_NAME \
            --restart always \
            --net=host \
            -v /var/run/docker.sock:/tmp/docker.sock \
            $DOCKER_URI \
            -internal -ip=$SERVICEIP \
            consul://$__stella_uri_address
        ;;

      proxy )
          __compute_var "proxygen"
          __log_run docker stop $SERVICE_NAME 2>/dev/null
          __log_run docker rm $SERVICE_NAME 2>/dev/null

          __compute_var "proxy"
          __log_run docker stop $SERVICE_NAME 2>/dev/null
          __log_run docker rm $SERVICE_NAME 2>/dev/null
          __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

          # launch reverse proxy
          __log_run docker run -d \
            --name=$SERVICE_NAME \
            --restart always \
            -p $PROXY:80 \
            -v $SERVICE_DATA_NAME:/etc/nginx/conf.d \
            $DOCKER_URI


          # launch nginx dynamic configurator
          __compute_var "proxygen"
          $STELLA_API uri_parse "$CONSUL"

          [ ! "$TEMPLATE" = "" ] && _OPT="-v $TEMPLATE:/tmp/nginx.ctmpl"
          __log_run docker run -d \
            --name=$SERVICE_NAME \
            --restart always \
            -e CONSUL_TEMPLATE_LOG=debug \
            --volumes-from ${DEFAULT_SERVICE_NAME}-proxy \
            -v /var/run/docker.sock:/tmp/docker.sock $_OPT \
            $DOCKER_URI \
            -consul-addr=$__stella_uri_address -wait=5s \
            -template="/tmp/nginx.ctmpl:/etc/nginx/conf.d/default.conf:docker kill -s HUP ${DEFAULT_SERVICE_NAME}-proxy"
        ;;
    esac
fi

if [ "$ACTION" = "start" ]; then
    __compute_var "$TARGET"
    __log_run docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
    __compute_var "$TARGET"
    __log_run docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
    __compute_var "$TARGET"
    __log_run docker stats $SERVICE_NAME
fi

if [ "$ACTION" = "shell" ]; then
    __compute_var "$TARGET"
    __log_run docker exec -it $SERVICE_NAME sh
fi

if [ "$ACTION" = "purge" ]; then
  case $TARGET in
    proxygen )
      echo "** ERROR : use proxy instead. proxy & proxygen are purged together"
      exit 1
    ;;
    proxy )
      __compute_var "proxygen"
      __log_run docker stop $SERVICE_NAME 2>/dev/null
      __log_run docker rm $SERVICE_NAME 2>/dev/null
      __log_run docker rmi $DOCKER_URI 2>/dev/null

      __compute_var "proxy"
      __log_run docker stop $SERVICE_NAME 2>/dev/null
      __log_run docker rm $SERVICE_NAME 2>/dev/null
      __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
      __log_run docker rmi $DOCKER_URI 2>/dev/null
    ;;

    *)
      __compute_var "$TARGET"
      # remove cntainers
      __log_run docker stop $SERVICE_NAME 2>/dev/null
      __log_run docker rm $SERVICE_NAME 2>/dev/null
      [ "$TARGET" = "proxy" ] && __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
      # remove image
      __log_run docker rmi $DOCKER_URI 2>/dev/null
    ;;
  esac

fi
