#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://docs.docker.com/engine/installation/linux/ubuntu/
# https://docs.docker.com/engine/installation/linux/linux-postinstall/

function usage() {
	echo "USAGE :"
  echo "deploy docker on ubuntu system"
	echo "NOTE : require to be run as root/sudo"
	echo "----------------"
	echo "o-- parametres :"
	echo "L     prepare : prepare system (use it once)"
	echo "L     install : deploy docker (must have run prepare command at least once)"
	echo "L     list : list available version (must have run prepare command at least once)"
	echo "L     purge : remove docker from system and remove all images, containers and volume"
	echo "o-- options :"
	echo "L     --version : docker-engine ubuntu version"
}
# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'prepare install list'
"
OPTIONS="
VERSION='' 			'v' 			'string'				s 			0			''		  Docker Engine ubuntu version (use list command to see available version).
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "docker-ubuntu-deploy" "$(usage)" "APPARG" "$@"


_check_root() {
	if [ "$(id -u)" -ne 0 ]; then
		echo "** ERROR : please run with root/sudo."
		exit 1
	fi
}

# NOTE : run with sudo
if [ "$ACTION" = "prepare" ]; then
	_check_root

	apt-get -y --no-install-recommends install curl apt-transport-https ca-certificates curl  software-properties-common
	curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -
	add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       ubuntu-$(lsb_release -cs) \
       main"

	apt-get update


	groupadd docker
fi
if [ "$ACTION" = "list" ]; then
	_check_root
	apt-get update
	apt-cache madison docker-engine
fi

if [ "$ACTION" = "install" ]; then
	_check_root

	apt-get update
	if [ -z "$VERSION" ]; then
		apt-get -y install docker-engine
	else
		apt-get -y install docker-engine=$VERSION
	fi
fi

if [ "$ACTION" = "purge" ]; then
	_check_root
	apt-get purge docker-engine
	rm -rf /var/lib/docker
fi
