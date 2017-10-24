#!/bin/bash

set -eu

cd $(dirname $0)

# Python virtualenv to use.
ENVIRONMENT="$HOME/Code/Gen3"

if [ "${ENVIRONMENT}" != "${VIRTUAL_ENV}" ]; then
    export PS1=""
    source $ENVIRONMENT/bin/activate
fi

python run.py &> .user-api.log &
export USER_API_PID=$!
echo "USERAPI   $USER_API_PID" | tee -a /tmp/data-portal-pids

