#!/bin/bash

source "${LITTLE_HOME}/lib/bash/utils.sh"


# lib ------------------------

secretCreate() {
    local name
    local value
    local description
    if [[ $# -lt 3 ]]; then
        gen3_log_err "secretCreate takes 3 arguments: name value description"
        return 1
    fi
    name="$1"
    shift
    value="$1"
    shift
    description="$1"
    shift
    local nameList=(${name//\// })
    if [[ ${#nameList[@]} != 5 ]]; then
        gen3_log_err "ERROR: name should have form org/project/stack/stage/role: $name"
        return 1
    fi
    local org="${nameList[0]}"
    local project="${nameList[1]}"
    local stack="${nameList[2]}"
    local stage="${nameList[3]}"
    local role="${nameList[4]}"
    local skeleton
    # uniquely identify the secret version
    local reqToken="$(uuidgen)-create-$(date +%Y-%m-%d-%H-%M-%S)"

    skeleton="$(
        cat - <<EOM
{
    "Name": "$org/$project/$stack/$stage/$role",
    "ClientRequestToken": "$reqToken",
    "Description": "$description",
    "SecretString": "$value",
    "Tags": [
        {
            "Key": "org",
            "Value": "$org"
        },
        {
            "Key": "project",
            "Value": "$project"
        },
        {
            "Key": "stack",
            "Value": "$stack"
        },
        {
            "Key": "stage",
            "Value": "$stage"
        },
        {
            "Key": "role",
            "Value": "$role"
        }
    ]
}
EOM
        )"
    aws secretsmanager create-secret --cli-input-json "$skeleton"
    return 0
}

secretLookup() {
    local name
    if [[ $# -lt 1 ]]; then
        gen3_log_err "secretLookup requires name"
        return 1
    fi
    name="$1"
    aws secretsmanager list-secrets | jq -r -e --arg name "$name" '.SecretList[] | select(.Name==$name)'
}


# main -----------------

if [[ $# -lt 1 || $1 =~ ^-*h(elp)?$ ]]; then
  arun help secret
  exit 1
fi

command="$1"
shift

case "$command" in
    "create")
        secretCreate "$@"
        ;;
    "lookup")
        secretLookup "$@"
        ;;
    *)
        arun help secret
        ;;
esac
