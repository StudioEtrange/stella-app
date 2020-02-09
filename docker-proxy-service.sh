#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="consul-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


# NOTE :
# Use order :
# 0 deploy consul (from consul-service)
# 1 deploy proxy and proxy-gen
# 2 deploy registrator

# consul & proxy (and proxy-gen) should be deployed only on ONE main node
# registrator should be deployed on any scanned node

# -------- TIPS --------
# see current nginx config
# docker exec docker-proxy-service-proxygen cat /etc/nginx/conf/default.conf

# see nginx proxy logs
# docker logs docker-proxy-service-proxy

# test current nginx config
# docker exec docker-proxy-service-proxy nginx -t

# see env enregistring
# docker logs docker-proxy-service-registrator

# -------- FULL SAMPLES with docker-machine --------
# ./stella-link.sh feature install docker
# ./stella-link.sh feature install docker-machine
# ./stella-link.sh boot shell local
# docker-machine create test
# eval $(docker-machine env test)

# create base services :
# ./consul-service.sh create 1 server -d --http=8500 --ip=$(docker-machine ip $DOCKER_MACHINE_NAME)
# docker logs consul-service-1
# ./docker-proxy-service.sh create registrator -d --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --serviceip=$(docker-machine ip $DOCKER_MACHINE_NAME)
# docker logs docker-proxy-service-registrator



# EXAMPLE : hello world
# FIRST launch consul and registrator (see above)
# ./docker-proxy-service.sh create proxy -d --proxy=80 --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --template=$(pwd)/docker-proxy-pool/nginx-hello-world.ctmpl
# docker logs docker-proxy-service-proxygen
# docker run --name hello-world-1 -l SERVICE_NAME=hello-world -d -p 80 tutum/hello-world
# see generated conf :
# docker run -it --volumes-from docker-proxy-service-proxy busybox more /etc/nginx/conf.d/default.conf
# see http://$DOCKER_MACHINE_NAME)
# see nginx proxy logs
# docker logs docker-proxy-service-proxy
# docker stop hello-world-1 && docker rm hello-world-1

# EXAMPLE : redirect with one service
# FIRST launch consul and registrator base services (see above)
# ./docker-proxy-service.sh create proxy -d --proxy=80 --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --template=$(pwd)/docker-proxy-pool/nginx-redirect.ctmpl
# docker run --name ghost -l SERVICE_NAME=ghost -l SERVICE_TAGS=redirect -d -P ghost
# docker logs docker-proxy-service-proxygen
# see generated conf :
# docker run -it --volumes-from docker-proxy-service-proxy busybox more /etc/nginx/conf.d/default.conf
# see http://$(docker-machine ip $DOCKER_MACHINE_NAME)/ghost
# see nginx proxy logs
# docker logs docker-proxy-service-proxy
# docker stop ghost && docker rm ghost

# EXAMPLE : redirect with several services into a single container
# FIRST launch consul and registrator base services (see above)
# ./docker-proxy-service.sh create proxy -d --proxy=80 --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --template=$(pwd)/docker-proxy-pool/nginx-redirect-multi.ctmpl
# launch image https://hub.docker.com/r/nshou/elasticsearch-kibana/ which have 2 services (5601 kibana, 9200 elasticsearch). We want to redirect the 2 services :
# docker run --name elk -p 2000:5601 -p 2001:9200 -l SERVICE_NAME=elkmulti -l SERVICE_5601_NAME=elkmulti -l SERVICE_9200_NAME=elkmulti -l SERVICE_5601_TAGS=redirect,kibana -l SERVICE_9200_TAGS=redirect,elastic -d nshou/elasticsearch-kibana:kibana5
# docker logs docker-proxy-service-proxygen
# see generated conf :
# docker run -it --volumes-from docker-proxy-service-proxy busybox more /etc/nginx/conf.d/default.conf
# see http://$(docker-machine ip $DOCKER_MACHINE_NAME)/elkmulti/kibana and http://$(docker-machine ip $DOCKER_MACHINE_NAME)/elkmulti/elastic
# see nginx proxy logs
# docker logs docker-proxy-service-proxy
# docker stop elk && docker rm elk

# EXAMPLE : reverse proxy with several services into a single container
# FIRST launch consul and registrator base services (see above)
# ./docker-proxy-service.sh create proxy -d --proxy=80 --consul=$(docker-machine ip $DOCKER_MACHINE_NAME):8500 --template=$(pwd)/docker-proxy-pool/nginx-rproxy-multi.ctmpl
# launch image https://hub.docker.com/r/samuelebistoletti/docker-statsd-influxdb-grafana/ which have 5 services (3003 grafana, 8083 influxdb-admin, 8086 influxdb, 8125 statsd,  22 sshd). We want to reverse proxy 3 services only (3003, 8083 and 8086).
# docker run --name ig -p 3000:3003 -p 3001:8083 -p 3002:8086 -p 22022:22 -p 8125:8125/udp -l SERVICE_NAME=influxmulti -l SERVICE_8083_NAME=influxmulti -l SERVICE_3003_NAME=influxmulti -l SERVICE_8086_NAME=influxmulti -l SERVICE_8083_TAGS=rproxy,rproxy-subpath,admin -l SERVICE_8086_TAGS=rproxy,rproxy-subpath,influxdb -l SERVICE_3003_TAGS=rproxy,rproxy-raw,/ -d samuelebistoletti/docker-statsd-influxdb-grafana:2.0.0
# docker logs docker-proxy-service-proxygen
# see generated conf :
# docker run -it --volumes-from docker-proxy-service-proxy busybox more /etc/nginx/conf.d/default.conf
# see http://$(docker-machine ip $DOCKER_MACHINE_NAME)/influxmulti/admin and http://$(docker-machine ip $DOCKER_MACHINE_NAME)/influxmulti/influxdb and http://$(docker-machine ip $DOCKER_MACHINE_NAME)/
# see nginx proxy logs
# docker logs docker-proxy-service-proxy
# docker stop ig && docker rm ig

# NOTE for macos docker desktop
#     We use --net=host on container'proxygen'. Because we need to reach consul at 'localhost'

# SERVICE INFO --------------------------------------
DEFAULT_SERVICE_NAME="docker-proxy-service"
DEFAULT_CONSUL_URI=localhost:8500
DEFAULT_PROXY_PORT=80
DEFAULT_SERVICE_IP=$STELLA_HOST_DEFAULT_IP
#DEFAULT_TEMPLATE="$STELLA_APP_ROOT/docker-proxy-pool/nginx.ctmpl"
DEFAULT_TEMPLATE=

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE_registrator="gliderlabs/registrator"
DEFAULT_DOCKER_IMAGE_VERSION_registrator="v7"
DEFAULT_DOCKER_IMAGE_proxy="nginx"
DEFAULT_DOCKER_IMAGE_VERSION_proxy="1.12.2-alpine"
DEFAULT_DOCKER_IMAGE_proxygen="studioetrange/docker-consul-template"
DEFAULT_DOCKER_IMAGE_VERSION_proxygen="0.19.5"

# NOTE there might be problems between registrator v7 and if consul version > 1.1.0
# for SERVICE_CHECK_SCRIPT registrator feature
# https://github.com/gliderlabs/registrator/issues/637
# https://github.com/gliderlabs/registrator/pull/643/commits/16d6db15ba603e2d880252e848d77661d5453a85



# USAGE --------------------------------------
function usage() {
  echo "USAGE :"
  echo "Provide an auto-configured reverse proxy for deployed docker."
  echo "NOTE : require docker on your system"
  echo "NOTE : It use registrator, nginx (as Proxy), and consul-template (as Proxygen)."
  echo "       As a requirements docker-proxy-service needs consul. You may deploy consul with consul-service"
  echo "----------------"
  echo "o-- command :"
  echo "L     create <proxy> [--version=<version>] [--consul=<uri>] [--proxy=<port>] [--template=<path>] [-- additional docker run options] : create & launch proxy/proxygen service (must be use once before starting/stopping service). Proxy and Proxy-gen are created together."
  echo "L     create <registrator> [--version=<version>] [--consul=<uri>] [--serviceip=<ip>|--serviceif=<interface>] [-- additional docker run options] : create & launch registrator service (must be use once before starting/stopping service)."
  echo "L     start <registrator|proxy|proxygen> : start service"
  echo "L     stop <registrator|proxy|proxygen> : stop service"
  echo "L     status <registrator|proxy|proxygen> : give service status info"
  echo "L     resync registrator [--version=<version>] [--consul=<uri>] [--serviceip=<ip>|--serviceif=<interface>] [-- additional docker run options] : resync container with consul. During time : 5seconds"
  echo "L     shell <registrator|proxy|proxygen> : launch a shell inside running service"
  echo "L     destroy <registrator|proxy> [--version=<version>] : destroy service"
  echo "o-- options :"
  echo "L     --consul : consul http api uri"
  echo "L     --proxy : reverse proxy port"
  echo "L     --serviceip : IP on which detected services by registrator are considered exposed. (Use serviceip OR serviceif. serviceif have priority)"
  echo "L     --serviceif : Network Interface on which detected services by registrator are considered exposed. (Use serviceip OR serviceif. serviceif have priority)"
  echo "L     --template : path to a template file for proxy-gen (ex: nginx.ctml)"
  echo "L     --version : item version"
  echo "L     --debug : active some debug trace"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'resync create start stop status shell destroy' '1'
TARGET=											'' 			a				'registrator proxy proxygen' '1'
"
OPTIONS="
CONSUL='$DEFAULT_CONSUL_URI' 						'' 			'string'				s 			0			''		  Consul URI.
PROXY='$DEFAULT_PROXY_PORT' 						'' 			'string'				s 			0			''		  Reverse proxy port.
SERVICEIP='$DEFAULT_SERVICE_IP' 						'' 			'string'				s 			0			''		  IP on which detected services by registrator are exposed.
SERVICEIF='' 						'' 			'string'				s 			0			''		   Network Interface on which detected services by registrator are exposed.
VERSION='' 			    'v' 			'string'				s 			0			''		  Docker image version.
TEMPLATE='$DEFAULT_TEMPLATE' 						'' 			'string'				s 			0			''		  Template file for proxy-gen (ex : /path/nginx.ctmpl).
DEBUG=''            'd'    		''            		b     		0     		'1'           		Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "EXTRA_ARG DOCKERARG" "$@"

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

# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------


# ------------- ACTIONS -------------------------
if [ "$ACTION" = "create" ]; then


    case $TARGET in
      proxygen)
          echo "** ERROR : use proxy instead. proxy & proxygen are created together"
          exit 1
        ;;

      registrator )
          __compute_var "registrator"
          __log_run docker stop $SERVICE_NAME 2>/dev/null
          __log_run docker rm $SERVICE_NAME 2>/dev/null

          $STELLA_API uri_parse "$CONSUL"

          [ ! "$SERVICEIF" = "" ] && SERVICEIP="$($STELLA_API get_ip_from_interface $SERVICEIF)"

          # NOTE : registrator -cleanup, clean dangling docker in consul when registrator start
          if [ "$SERVICEIP" = "" ]; then
            __log_run docker run -d \
              --name=$SERVICE_NAME \
              --restart always \
              --net=host \
              -v /var/run/docker.sock:/tmp/docker.sock \
              $DOCKERARG $DOCKER_URI \
              -cleanup \
              consul://$__stella_uri_address
          else
            __log_run docker run -d \
              --name=$SERVICE_NAME \
              --restart always \
              --net=host \
              -v /var/run/docker.sock:/tmp/docker.sock \
              $DOCKERARG $DOCKER_URI \
              -ip=$SERVICEIP \
              -cleanup \
              consul://$__stella_uri_address
          fi
        ;;

      proxy )
          __compute_var "proxygen"
          __log_run docker stop $SERVICE_NAME 2>/dev/null
          __log_run docker rm $SERVICE_NAME 2>/dev/null

          __compute_var "proxy"
          __log_run docker stop $SERVICE_NAME 2>/dev/null
          __log_run docker rm $SERVICE_NAME 2>/dev/null
          __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null

          # launch nginx reverse proxy
          __log_run docker run -d \
            --name=$SERVICE_NAME \
            --restart always \
            -p $PROXY:80 \
            -v $SERVICE_DATA_NAME:/etc/nginx/conf.d \
            $DOCKERARG $DOCKER_URI


          # launch nginx dynamic configurator
          __compute_var "proxygen"
          $STELLA_API uri_parse "$CONSUL"

          [ ! "$TEMPLATE" = "" ] && _OPT="-v $TEMPLATE:/tmp/nginx.ctmpl"
          __log_run docker run -d \
            --name=$SERVICE_NAME \
            --restart always \
            --net=host \
            -e CONSUL_TEMPLATE_LOG=debug \
            --volumes-from ${DEFAULT_SERVICE_NAME}-proxy \
            -v /var/run/docker.sock:/tmp/docker.sock $_OPT \
            $DOCKERARG $DOCKER_URI \
            -consul-addr=$__stella_uri_address -wait=5s \
            -template="/tmp/nginx.ctmpl:/etc/nginx/conf.d/default.conf:docker kill -s HUP ${DEFAULT_SERVICE_NAME}-proxy"
        ;;
    esac
fi

if [ "$ACTION" = "resync" ]; then
    if [ "$TARGET" = "registrator" ]; then
      __compute_var "registrator"
      $STELLA_API uri_parse "$CONSUL"

      [ ! "$SERVICEIF" = "" ] && SERVICEIP="$($STELLA_API get_ip_from_interface $SERVICEIF)"

       echo "** Try to resync container with discovery service in a window time of 5 seconds"
      if [ "$SERVICEIP" = "" ]; then
        __log_run docker exec \
          $DOCKERARG \
          -t \
          $SERVICE_NAME \
          timeout -t 5 sh -c "registrator -retry-attempts=0 -retry-interval=2000 -cleanup consul://$__stella_uri_address"
      else
        __log_run docker exec \
          $DOCKERARG \
          -t \
          $SERVICE_NAME \
          timeout -t 5 sh -c "registrator -retry-attempts=0 -retry-interval=2000 -cleanup -ip=$SERVICEIP consul://$__stella_uri_address"
      fi
    fi
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

if [ "$ACTION" = "destroy" ]; then
  case $TARGET in
    proxygen )
      echo "** ERROR : proxy & proxygen are destroyed together"
      echo "           use command : $0 destroy proxy"
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
      [ ! "${NOPURGE}" = "1" ] && __log_run docker volume rm $SERVICE_DATA_NAME 2>/dev/null
      __log_run docker rmi $DOCKER_URI 2>/dev/null
    ;;

    registrator )
      __compute_var "$TARGET"
      __log_run docker stop $SERVICE_NAME 2>/dev/null
      __log_run docker rm $SERVICE_NAME 2>/dev/null
      # remove image
      __log_run docker rmi $DOCKER_URI 2>/dev/null
    ;;
  esac

fi
