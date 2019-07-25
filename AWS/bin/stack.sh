#!/bin/bash


set -e

# globals -------------------

profile="${AWS_PROFILE:-default}"

if ! region="$(aws --profile "$profile" configure get region)"; then
    echo "ERROR: aws configure get region failed" 1>&2
    return 1
fi

bucket="cloudformation-frickjack-$region"
accountId="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"

# lib ------------------------

help() {
    bash "$LITTLE_HOME/bin/help.sh" stack
}

# 
# Apply a cloudformation update or create
#
# @param commandStr --update or --create
# @param templatePath
# @param stackPath
#
apply() {
    local reqToken
    local skeleton
    local commandStr
    local templatePath
    local stackPath
    local stackName
    local s3Path

    if [[ $# -lt 3 || ! $1 =~ ^-*(update|create)$ ]]; then
        echo "ERROR: apply must specify update or create" 1>&2
        return 1
    fi
    if [[ $1 =~ ^-*update$ ]]; then
        commandStr="update-stack"
    elif [[ "$1" =~ ^-*create$ ]]; then
        commandStr="create-stack"
    else
        echo "ERROR: invalid apply command: $@" 1>&2
        return 1
    fi
    shift
    templatePath="$1"
    shift
    stackPath="$1"
    shift
    if [[ ! -f "$templatePath" ]]; then
        echo "ERROR: unable to load template $templatePath" 1>&2
        return 1
    fi
    if [[ ! -f "$stackPath" || ! stackName="$(jq -r -e .StackName < "$stackPath")" ]]; then
        echo "ERROR: unable to load stackName from $stackPath" 1>&2
        return 1
    fi
    s3Path="cf/$stackName/${templatePath##*/}"
   
    # uniquely identify the update-stack request
    reqToken="apply-$(date +%Y-%m-%d-%H-%M-%S)"

    aws cloudformation validate-template --template-body "$(cat "$templatePath")"
    aws s3 cp "$templatePath" "s3://${bucket}/$s3Path"

    skeleton="$(
        cat "$stackPath" | \
        jq -r -e --arg url "https://${bucket}.s3.amazonaws.com/${s3Path}" '.TemplateURL=$url' | \
        jq -r -e --arg token "$reqToken" '.ClientRequestToken=$token'    
    )"
    if [[ "$commandStr" == "update-stack" ]]; then
        if ! skeleton="$(echo "$skeleton" | jq -r -e 'del(.TimeoutInMinutes) | del(.EnableTerminationProtection)')"; then
            echo "ERROR: failed to process $skeleton" 1>&2
            return 1
        fi
    fi
    cat - 1>&2 <<EOM
INFO: attempting to update stack:
$skeleton
EOM
    if aws cloudformation "${commandStr}" --cli-input-json "$skeleton"; then
      echo "INFO: Successfully submitted stack: $stackName" 1>&2
    fi
}

create() {
  apply --create "$@"
}


update() {
  apply --update "$@"
}

delete() {
    local stackPath
    local stackName

    while [[ $# -gt 0 ]]; do
      stackPath="$1"
      shift
    done
    
    if [[ ! -f "$stackPath" ]] || ! stackName="$(jq -e -r .StackName < "$stackPath")"; then
      echo "ERROR: unable to load name from stack skeleton: $stackPath" 1>&2
      return 1
    fi
    aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name "$stackName"
    aws cloudformation delete-stack --stack-name "$stackName"
}


events() {
    local stackPath
    local stackName

    while [[ $# -gt 0 ]]; do
      stackPath="$1"
      shift
    done
    
    if [[ ! -f "$stackPath" ]] || ! stackName="$(jq -e -r .StackName < "$stackPath")"; then
      echo "ERROR: unable to load name from stack skeleton: $stackPath" 1>&2
      return 1
    fi
    aws cloudformation describe-stack-events --stack-name "$stackName"
}


list() {
    local cliInput
    cliInput="$(cat - <<EOM
{
    "StackStatusFilter": [
            "ROLLBACK_IN_PROGRESS",
            "CREATE_IN_PROGRESS",
            "CREATE_COMPLETE",
            "ROLLBACK_IN_PROGRESS",
            "ROLLBACK_FAILED",
            "ROLLBACK_COMPLETE",
            "DELETE_IN_PROGRESS",
            "DELETE_FAILED",
            "UPDATE_IN_PROGRESS",
            "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS",
            "UPDATE_COMPLETE",
            "UPDATE_ROLLBACK_IN_PROGRESS",
            "UPDATE_ROLLBACK_FAILED",
            "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS",
            "UPDATE_ROLLBACK_COMPLETE",
            "REVIEW_IN_PROGRESS"
    ]
}
EOM
    )";
    aws cloudformation list-stacks --cli-input-json "${cliInput}"
}

validate() {
    local templatePath
    if [[ $# -lt 1 ]]; then
      echo "ERROR: validate requires path to template" 1>&2
      return 1
    fi
    templatePath="$1"
    shift
    aws cloudformation validate-template --template-body "$(cat "$templatePath")"
}

# main -----------------

if [[ $# -lt 1 || $1 =~ ^-*h(elp)?$ ]]; then
  help
  exit 1
fi

command="$1"
shift

case "$command" in
    "bucket")
        echo "$bucket"
        ;;
    "create")
        create "$@"
        ;;
    "delete")
        delete "$@"
        ;;
    "events")
        events "$@"
        ;;
    "list")
        list "$@"
        ;;
    "update")
        update "$@"
        ;;
    "validate")
        validate "$@"
        ;;
    *)
        help
        ;;
esac
