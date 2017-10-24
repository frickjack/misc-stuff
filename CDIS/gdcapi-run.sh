#!/bin/bash

set -eu

cd $(dirname $0)

# Python virtualenv to use.
ENVIRONMENT="$HOME/Code/Gen3"

if [ "${ENVIRONMENT}" != "${VIRTUAL_ENV}" ]; then
    export PS1=""
    source $ENVIRONMENT/bin/activate
fi

python run.py &> .gdcapi.log &
export GDCAPI_PID=$!
echo "GDCAPI   $GDCAPI_PID" | tee -a /tmp/data-portal-pids

