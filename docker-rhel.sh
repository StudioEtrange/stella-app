#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
. $_CURRENT_FILE_DIR/stella-link.sh include

# https://docs.docker.com/engine/installation/linux/rhel/
# https://docs.docker.com/engine/installation/linux/linux-postinstall/

function usage() {
	echo "USAGE :"
  echo "deploy docker on red hat/centos system"
	echo "NOTE : require to be run as root/sudo"
	echo "----------------"
	echo "o-- parametres :"
	echo "L     init : prepare system for install (use it once)"
	echo "L     install : deploy docker (must have run prepare command at least once)"
	echo "L     list : list available version (must have run prepare command at least once)"
	echo "L     purge : remove docker from system and remove all images, containers and volume"
	echo "o-- options :"
	echo "L     --version : docker-engine rhel version"
}
# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
ACTION=											'' 			a				'init install list purge'
"
OPTIONS="
VERSION='' 			'v' 			'string'				s 			0			''		  Docker Engine rhel version (use list command to see available version).
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "docker-rhel" "$(usage)" "APPARG" "$@"


_check_root() {
	if [ "$(id -u)" -ne 0 ]; then
		echo "** ERROR : please run with root/sudo."
		exit 1
	fi
}

# NOTE :
# to remove old version
# sudo yum -y remove docker docker-common container-selinux
# sudo yum -y remove docker-selinux
if [ "$ACTION" = "init" ]; then
	_check_root


	yum install -y yum-utils
	# The link is correct for RHEL as well as CentOS.
	yum-config-manager \
    --add-repo \
    https://docs.docker.com/engine/installation/linux/repo_files/centos/docker.repo


	#yum-config-manager --set-enabled docker-testing
	#yum-config-manager --set-disabled docker-testing

	yum makecache fast

	groupadd docker
fi

if [ "$ACTION" = "list" ]; then
	_check_root
	yum makecache fast
	yum list docker-engine.x86_64 --showduplicates |sort -r
fi

if [ "$ACTION" = "install" ]; then
	_check_root

	yum makecache fast
	if [ -z "$VERSION" ]; then
		yum -y install docker-engine
	else
		yum -y install docker-engine-$VERSION
	fi

	systemctl start docker

	echo "*** NOTE : to run docker client without root/sudo, please add user to group docker"
	echo " sudo usermod -aG docker <user>"
	echo " do not forget to logout/login after a user is affected to docker group"

	echo "*** NOTE : docker service is managed with systemctl"
	echo "systemctl start|stop docker"
fi

if [ "$ACTION" = "purge" ]; then
	_check_root
	# deprecated packages
	yum -y remove docker docker-common container-selinux
	yum -y remove docker-selinux
	# new package
	yum -y remove docker-engine
	rm -rf /var/lib/docker
fi
