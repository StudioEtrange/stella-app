

# TODO do a full convert to stella-app

# TODO do a full convert to stella-app

# TODO do a full convert to stella-app

# TODO do a full convert to stella-app

#!/bin/bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
. $_CURRENT_FILE_DIR/stella-link.sh include

# http://gitlab.acc.edf.fr/boucault-syl/docker-wekan-mgt
# https://github.com/wekan/wekan/wiki/Install-Wekan-Docker-for-testing



function usage() {
	echo "USAGE :"
	echo "----------------"
	echo "o-- general management :"
	echo "L     install docker : (system widely)"
	echo "L     install tools"
	echo "L	    install env"
	echo "L			docker proxy --proxy=<host:port> : set a proxy to docker daemon and restart service (do not pass value to unset proxy)"
	echo "L	    wekan run|stop"
	echo "L	    wekan build|remove"
	echo "L			wekan status : report wekan containers status"
}

# COMMAND LINE -----------------------------------------------------------------------------------
PARAMETERS="
DOMAIN=											'domain' 			a				'install wekan docker'
ID=												'' 					a	 	'docker tools env run stop build remove proxy status'
"
OPTIONS="
FORCE=''				   'f'		  ''					b			0		'1'					  Force.
WHOST='$STELLA_HOST_DEFAULT_IP' 				'' 			'string'				s 			0			''		  Wekan external host/dns name.
WPORT='8181' 				'' 			'string'				s 			0			''		  Wekan listen port.
WHOME='/var/opt/wekan' 				'' 			'string'				s 			0			''		  Wekan directory to store data.
PROXY=''				'' 			'string'				s 			0			''		  Wekan listen port.
"
$STELLA_API argparse "$0" "$OPTIONS" "$PARAMETERS" "docker-wekan-mgt" "$(usage)" "APPARG" "$@"

#-------------------------------------------------------------------------------------------
export WEKAN_HOME=$WHOME
export WEKAN_HOST=$WHOST
export WEKAN_PORT=$WPORT



# --------------- INSTALL ----------------------------
if [ "$DOMAIN" == "install" ]; then

	

	if [ "$ID" == "env" ]; then
		echo "** Prepare environnement for running a dockerized wekan (may need sudo/root)"

		mkdir -p $WEKAN_HOME
		if [ ! -d "$WEKAN_HOME" ]; then
			echo " ERROR : not enough rights to create $WEKAN_HOME. Try with (sudo/root)"
			exit 1
		fi
		mkdir -p $WEKAN_HOME/maildirs
	fi
fi

# ------------- ENV ----------------------------
if [ "$DOMAIN" == "docker" ]; then
	if [ "$ID" == "proxy" ]; then
			# https://docs.docker.com/engine/admin/systemd/#/http-proxy
			mkdir -p /etc/systemd/system/docker.service.d
			echo "[Service]" > /etc/systemd/system/docker.service.d/http-proxy.conf
			echo "Environment=\"HTTP_PROXY=$PROXY\" \"HTTPS_PROXY=$PROXY\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf
			sudo systemctl daemon-reload
			systemctl show --property=Environment docker
			sudo systemctl restart docker
	fi
fi

# ------------- ENV ----------------------------
if [ "$DOMAIN" == "wekan" ]; then
	if [ "$ID" == "run" ]; then
		cd $STELLA_APP_ROOT
		docker-compose up -d
	fi

	if [ "$ID" == "stop" ]; then
		cd $STELLA_APP_ROOT
		docker-compose stop
	fi

	if [ "$ID" == "build" ]; then
		cd $STELLA_APP_ROOT
		echo "** Build Wekan services (with docker-compose)"
		echo "** Should be longer the first time"
		echo "** WARN : You NEED to have a web access"
		docker-compose build
	fi

	if [ "$ID" == "remove" ]; then
		cd $STELLA_APP_ROOT
		echo "** Remove built Wekan services. You will have to rebuilt them."
		docker-compose down
	fi

	if [ "$ID" == "status" ]; then
		cd $STELLA_APP_ROOT
		docker-compose ps
	fi

fi
