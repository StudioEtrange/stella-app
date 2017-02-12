#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
STELLA_APP_PROPERTIES_FILENAME="lightgbm-python.properties"
. $_CURRENT_FILE_DIR/stella-link.sh include


if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
 echo "deploy lightgbm python module in current python env"
 exit
fi


$STELLA_API feature_install lightgbm

$STELLA_API feature_info lightgbm LIGHTGBM
echo "lightgbm is in $LIGHTGBM_FEAT_INSTALL_ROOT"
cd $LIGHTGBM_FEAT_INSTALL_ROOT/python-package
python setup.py install
