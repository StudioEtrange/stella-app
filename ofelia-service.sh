#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="ofelia-service.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include

# 2019-02-28 : A lot of problems with ofelia appears to make ofelia not so interesting

# LINKS :
# https://github.com/mcuadros/ofelia
# schedule format : https://godoc.org/github.com/robfig/cron
# doc https://www.tikalk.com/posts/2018/05/08/ofelia-cron-tasks-on-steroids-in-docker/

# OFELIA FORK
# https://github.com/Postcon/ofelia : seems to have more features, and a special property for registry
# https://github.com/Trane9991/ofelia : add support to pass ofelia configuration with docker labels
# https://github.com/vigasin/ofelia : and support for bind mount volyme

# PROBLEMS :
# 1/ task job-local try to execute command inside ofelia container (not on host) which is a minimal go binary
# 2/ ofelia do not provide a way to mount volume, you have to create a container (maybe with docker-compose) before and use only task job-exec
# 3/ stdout log seems to not work. Might be a problem with AttachContainer not make like this https://github.com/fsouza/go-dockerclient/issues/310 https://gist.github.com/pwaller/314c7591a8bfd32f8999

# SERVICE INFO --------------------------------------
DEFAULT_OFELIA_JOB_STORE="$STELLA_APP_WORK_ROOT/ofelia-service-jobs"
DEFAULT_SERVICE_NAME="ofelia-scheduler"
DEFAULT_DOCKER_SOCKET="/var/run/docker.sock"
DEFAULT_CONFIG_FILE_NAME="config.ini"
DEFAULT_OFELIA_REPORT_OUTSIDE_STORE="$STELLA_APP_WORK_ROOT/ofelia-reports"
DEFAULT_OFELIA_REPORT_INSIDE_STORE="/ofelia-reports"

# DOCKER IMAGES INFO --------------------------------------
DEFAULT_DOCKER_IMAGE="mcuadros/ofelia"
DEFAULT_DOCKER_IMAGE_VERSION="latest"

function usage() {
  echo "USAGE :"
  echo "scheduler for job task based on ofelia"
  echo "NOTE : require docker on your system"
  echo "----------------"
  echo "o-- command :"
  echo "L     create <name> [--conf=<uri>] [--version=<version>] [--jobstore=<path>] [--reportstore=<path>] [--force] [-- additional docker run options] : create & launch a scheduled job"
  echo "L     start <name> : start service"
  echo "L     stop <name> : stop service"
  echo "L     destroy <name> [--version=<version>] [--jobstore=<path>] : stop, delete service and all image files. At next create, everything will be forced to be downloaded."
  echo "L     status <name> : give service status info"
  echo "L     list <all|user> : list all existing jobs or a specific user job"
  echo "L     info <name> : show information on a job"
  echo "L     logs <name> : show logs information of a job"
  echo "o-- options :"
  echo "L     --conf : uri to ofelia job configuration file"
  echo "L     --jobstore : job storage path"
  echo "L     --reportstore : report storage path"
  echo "L     --version : ofelia version"
  echo "L     --debug : active some debug trace"
  echo "L     --force : force action"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a			'create start stop status destroy list info logs' '1'
JOB=											'' 			s				'' '1'
"
OPTIONS="
FORCE='0'            'f'    		''            		b     		0     		'1'           			Force current action.
CONF='' 						'' 			'uri'				s 			0			''		  Uri to to ofelia job configuration file.
PORT='$DEFAULT_PORT' 						'' 			'string'				s 			0			''		  Listening netdata port.
JOBSTORE='$DEFAULT_OFELIA_JOB_STORE' 						'' 			'path'				s 			0			''		  Job storage path.
REPORTSTORE='$DEFAULT_OFELIA_REPORT_OUTSIDE_STORE' 						'' 			'path'				s 			0			''		  Report storage path.
VERSION='$DEFAULT_DOCKER_IMAGE_VERSION' 			'v' 			'string'				s 			0			''		  Netdata version (check available version on netdata website).
DEBUG='0'            'd'    		''            		b     		0     		'1'           			Active some debug trace.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "$STELLA_APP_NAME" "$(usage)" "EXTRA_ARG DOCKERARG" "$@"


# FUNCTIONS --------------------------------------
__log_run() {
	[ "$DEBUG" = "1" ] && echo ">" $@
	"$@"
}

__container_name_validate() {
	valid='0-9a-zA-Z_-'
	if [[ ! $1 =~ [^$valid] ]]; then
		# valide
		echo "1"
	else
		echo "0"
	fi
}


__job_exist() {
  _name="$1"
  [ -d "${OFELIA_JOB_STORE}/${_name}" ] && echo "1" || echo "0"
}

__job_info() {
  _name="$1"
  echo "---=- Job [${_name}] -=---"
  echo "Status : $(__get_docker_status ${DEFAULT_SERVICE_NAME}-${_name})"
  echo
  echo "---=- Job [${_name}] tasks information -=---"
  sed -n -e 's/^command[[:space:]]*=\(.*\)$/command\:\1/p' -e 's/^container[[:space:]]*=\(.*\)$/container\:\1/p' -e 's/^image[[:space:]]*=\(.*\)$/image:\1/p' -e 's/^schedule[[:space:]]*=\(.*\)$/schedule:\1/p' -e 's/^\[\(job[^\]*\)\]$/=== Task:\1 ===/p' "${OFELIA_JOB_STORE}/${JOB}/${DEFAULT_CONFIG_FILE_NAME}"
}

__job_extract_task_list() {
  _name="$1"
  __task_list=$(sed -n  -e 's/^\[\(job[^\]*\)\]$/\1/p' "${OFELIA_JOB_STORE}/${_name}/${DEFAULT_CONFIG_FILE_NAME}" | tr '\n' '|' | sed  -e 's/|/ | /g')
  echo "${__task_list}"
}

__job_extract_schedule_list() {
  _name="$1"
  __schedule_list=$(sed -n  -e 's/^schedule[[:space:]]*=\(.*\)$/\1/p' "${OFELIA_JOB_STORE}/${_name}/${DEFAULT_CONFIG_FILE_NAME}" | tr '\n' '|' | sed  -e 's/|/ | /g')
  echo "${__schedule_list}"
}

# get a container status
__get_docker_status() {
	__object_name="$1"
  __result="unknown"
  if [ ! "$(docker ps -aq -f name="^/${__object_name}$")" = "" ]; then
	   __result="$(docker inspect --format='{{.State.Status}}' "${__object_name}")"
  fi
	echo "$__result"
}


# ------------- COMPUTE ARGUMENTS AND VALUES -------------------------
DOCKER_IMAGE_VERSION=$VERSION
DOCKER_URI=$DEFAULT_DOCKER_IMAGE
[ ! -z "$DOCKER_IMAGE_VERSION" ] && DOCKER_URI=$DOCKER_URI:$DOCKER_IMAGE_VERSION
SERVICE_NAME=$DEFAULT_SERVICE_NAME


# job store folder
[ "${JOBSTORE}" = "" ] && OFELIA_JOB_STORE="${DEFAULT_OFELIA_JOB_STORE}" || OFELIA_JOB_STORE="${JOBSTORE}"
[ ! -d "${OFELIA_JOB_STORE}" ] && mkdir -p "${OFELIA_JOB_STORE}"
if [ ! -d "${OFELIA_JOB_STORE}" ]; then
  echo "ERROR : Job store path do not exist or cannot be created [${OFELIA_JOB_STORE}]"
  exit 1
fi

# report store folder
[ "${REPORTSTORE}" = "" ] && OFELIA_REPORT_STORE="${DEFAULT_OFELIA_REPORT_OUTSIDE_STORE}" || OFELIA_REPORT_STORE="${REPORTSTORE}"
[ ! -d "${OFELIA_REPORT_STORE}" ] && mkdir -p "${OFELIA_REPORT_STORE}"
if [ ! -d "${OFELIA_REPORT_STORE}" ]; then
  echo "ERROR : Report store path do not exist or cannot be created [${OFELIA_REPORT_STORE}]"
  exit 1
fi

# test docker client is installed in this system
$STELLA_API require "docker" "docker" "SYSTEM"




# ------------- ACTIONS -------------------------
# validate job name
case $ACTION in
  list )
    ;;
  * )
    if [ "$(__container_name_validate ${JOB})" = "0" ]; then
      echo "ERROR : invalid job name ${JOB}"
      exit 1
    fi
    SERVICE_NAME="${SERVICE_NAME}-${JOB}"
    ;;
esac


if [ "$ACTION" = "create" ]; then

  # check if job conf already exist
  if [ ! "$FORCE" = "1" ]; then
    if [ "$(__job_exist ${JOB})" = "1" ]; then
      echo "ERROR : job [${JOB}] already exist"
      exit 1
    fi
  fi

  # check job conf
  # TODO : take care of uri and not only file
  if [ ! -f "${CONF}" ]; then
    echo "ERROR : Wrong configuration file uri [${CONF}]"
    exit 1
  fi

  # delete previously stored container
  __log_run docker stop ${SERVICE_NAME} 2>/dev/null
  __log_run docker rm ${SERVICE_NAME} 2>/dev/null

  # manage job conf
  if [ "$(__job_exist ${JOB})" = "1" ]; then
    rm -Rf "${OFELIA_JOB_STORE}/${JOB}"
  fi
  # TODO : take care of uri and not only file
  mkdir -p "${OFELIA_JOB_STORE}/${JOB}"
  cp -f "${CONF}" "${OFELIA_JOB_STORE}/${JOB}/${DEFAULT_CONFIG_FILE_NAME}"
  # tweak ofelia report folder
  sed -i.bak -e 's,save-folder[[:space:]]*=\(.*\)$,save-folder='${DEFAULT_OFELIA_REPORT_INSIDE_STORE}',' "${OFELIA_JOB_STORE}/${JOB}/${DEFAULT_CONFIG_FILE_NAME}"

  __job_info "${JOB}"

  __log_run docker run -d \
              --name ${SERVICE_NAME} \
              --restart always \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -v ${OFELIA_REPORT_STORE}:${DEFAULT_OFELIA_REPORT_INSIDE_STORE} \
              -v ${OFELIA_JOB_STORE}/${JOB}:/etc/ofelia \
              -l ${DEFAULT_SERVICE_NAME}=1 -l ${DEFAULT_SERVICE_NAME}.user=${USER} \
              -l ${DEFAULT_SERVICE_NAME}.tasks="$(__job_extract_task_list ${JOB})" \
              -l ${DEFAULT_SERVICE_NAME}.schedule="$(__job_extract_schedule_list ${JOB})" \
              $DOCKERARG $DOCKER_URI
# -v /etc/localtime:/etc/localtime:ro -v /etc/timezone:/etc/timezone:ro
fi

if [ "$ACTION" = "destroy" ]; then
  __log_run docker stop $SERVICE_NAME 2>/dev/null
  __log_run docker rm $SERVICE_NAME 2>/dev/null
  #__log_run docker rmi $DOCKER_URI 2>/dev/null
  rm -Rf "${OFELIA_JOB_STORE}/${JOB}"
fi

if [ "$ACTION" = "start" ]; then
  __log_run docker start $SERVICE_NAME
fi

if [ "$ACTION" = "stop" ]; then
  __log_run docker stop $SERVICE_NAME
fi

if [ "$ACTION" = "status" ]; then
  #docker stats $SERVICE_NAME
  __log_run docker ps | grep $SERVICE_NAME
fi

if [ "$ACTION" = "info" ]; then
  __job_info "${JOB}"
fi

if [ "$ACTION" = "logs" ]; then
  __log_run docker logs -f $SERVICE_NAME
fi

if [ "$ACTION" = "list" ]; then
  if [ "$JOB" = "all" ]; then
    echo " ** List RUNNING jobs"
    docker ps -a --filter=label=${DEFAULT_SERVICE_NAME}=1 --filter=label=${DEFAULT_SERVICE_NAME}.user -f status=running --format "table {{.Label \"${DEFAULT_SERVICE_NAME}.user\"}}\t{{.Names}}\t\t{{.Status}}\t\t{{.Label \"${DEFAULT_SERVICE_NAME}.schedule\"}}"
    echo " ** List STOPPED jobs"
    docker ps -a --filter=label=${DEFAULT_SERVICE_NAME}=1 --filter=label=${DEFAULT_SERVICE_NAME}.user -f status=exited -f status=created --format "table {{.Label \"${DEFAULT_SERVICE_NAME}.user\"}}\t{{.Names}}\t\t{{.Status}}\t\t{{.Label \"${DEFAULT_SERVICE_NAME}.schedule\"}}"
  else
    echo " ** Jobs created by user ${JOB}"
    echo " ** List RUNNING"
    docker ps -a --filter=label=${DEFAULT_SERVICE_NAME}=1 --filter=label=${DEFAULT_SERVICE_NAME}.user="${JOB}" -f status=running --format "table {{.Label \"${DEFAULT_SERVICE_NAME}.user\"}}\t{{.Names}}\t\t{{.Status}}\t\t{{.Label \"${DEFAULT_SERVICE_NAME}.schedule\"}}"
    echo " ** List STOPPED"
    docker ps -a --filter=label=${DEFAULT_SERVICE_NAME}=1 --filter=label=${DEFAULT_SERVICE_NAME}.user="${JOB}" -f status=exited -f status=created --format "table {{.Label \"${DEFAULT_SERVICE_NAME}.user\"}}\t{{.Names}}\t\t{{.Status}}\t\t{{.Label \"${DEFAULT_SERVICE_NAME}.schedule\"}}"
  fi
fi
