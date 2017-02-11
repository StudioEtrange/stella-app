#!/usr/bin/env bash
_CURRENT_FILE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_CURRENT_RUNNING_DIR="$( cd "$( dirname "." )" && pwd )"
. $_CURRENT_FILE_DIR/stella-link.sh include


if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
 echo "deploy xgboost python module in current python env"
 exit
fi


$STELLA_API feature_install xgboost

$STELLA_API feature_info xgboost XGBOOST
echo "xgboost is in $XGBOOST_FEAT_INSTALL_ROOT"
cd $XGBOOST_FEAT_INSTALL_ROOT/python-package
python setup.py install
