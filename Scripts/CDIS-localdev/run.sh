#!/bin/bash
#
# See: https://github.com/uc-cdis/cdis-wiki/wiki/Local-development-for-Gen3
# Thanks, Rudy!
#

set -eu

# Directory where user-api, indexd, gdcapi, and data-portal directories live.
CDIS_HOME="$HOME/Code/PlanX"
# Python virtualenv to use.
ENVIRONMENT="$HOME/Code/PyEnv/Demo1"
# Port for indexd service to run on.
INDEXD_PORT=8888

export PS1=""
export GDC_PG_DBNAME=bhc_graph
source $ENVIRONMENT/bin/activate

cd $CDIS_HOME/user-api
python run.py &> .user-api.log &
export USER_API_PID=$!
echo "USERAPI    $USER_API_PID" | tee -a /tmp/data-portal-pids

cd $CDIS_HOME/indexd
./bin/indexd --port=$INDEXD_PORT &
export INDEXD_PID=$!
echo "INDEXD    $INDEXD_PID" | tee -a /tmp/data-portal-pids

cd $CDIS_HOME/gdcapi
python run.py &> .gdcapi.log &
export GDCAPI_PID=$!
echo "GDCAPI  $GDCAPI_PID" | tee -a /tmp/data-portal-pids

#
#cd $CDIS_HOME/data-portal
#export NODE_ENV=dev
#./node_modules/.bin/webpack-dev-server --hot &> .webpack-dev-server.log &
#export WEBPACK_SERVER_PID=$!
#echo "WEBPACK    $WEBPACK_SERVER_PID" | tee -a /tmp/data-portal-pids
#
