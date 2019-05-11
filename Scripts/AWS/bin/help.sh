#!/bin/bash


help() {
    cat - <<EOM
Use: arun [--profile PROFILE] command ...
EOM
    ls -1 Scripts/AWS/bin/ | sed -e 's/.sh$//'
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  help "$@"
fi
