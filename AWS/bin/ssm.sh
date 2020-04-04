#!/bin/bash

source "${LITTLE_HOME}/lib/bash/utils.sh"


# lib ------------------------

saveParameter() {
    local name
    local value
    local description
    if [[ $# -lt 3 ]]; then
        gen3_log_err "saveParameter takes 3 arguments: name value description"
        return 1
    fi
    name="$1"
    shift
    value="$1"
    shift
    description="$1"
    if [[ ! "$value" =~ ^\{.+:.+\}$ ]] || ! jq -e -r . <<<"$value" > /dev/null 2>&1; then
        gen3_log_err "invalid secret value - must be a json object"
        return 1
    fi
    local nameList=(${name//./ })
    if [[ ${#nameList[@]} != 5 ]]; then
        gen3_log_err "ERROR: name should have form org/project/stack/stage/role: $name"
        return 1
    fi
    local org="${nameList[0]}"
    local project="${nameList[1]}"
    local stack="${nameList[2]}"
    local stage="${nameList[3]}"
    local role="${nameList[4]}"
    local finalName="${org}.${project}.${stack}.${stage}.${role}"
    local skeleton

    skeleton="$(
        cat - <<EOM
{
    "Name": "${finalName}",
    "Description": "$description",
    "Value": "",
    "Type": "String",
    "Overwrite": true,
    "Tier": "Standard",
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
    skeleton="$(jq --arg value "$value" '.Value=$value' <<<"$skeleton")"
    if aws ssm get-parameter --name "$finalName" > /dev/null 2>&1; then
        # cannot apply tags on update
        skeleton="$(jq 'del(.Tags)' <<<"$skeleton")"
    else
        # no overwrite on create
        skeleton="$(jq 'del(.Overwrite)' <<<"$skeleton")"
    fi
    aws ssm put-parameter --cli-input-json "$skeleton"
}

# main -----------------

if [[ $# -lt 1 || $1 =~ ^-*h(elp)?$ ]]; then
  little help ssm
  exit 1
fi

command="$1"
shift

case "$command" in
    "put-parameter")
        saveParameter "$@"
        ;;
    *)
        gen3_log_err "unknown command: $command"
        little help ssm
        exit 1
        ;;
esac
