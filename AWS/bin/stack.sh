#!/bin/bash

source "${LITTLE_HOME}/lib/bash/utils.sh"

# globals --------------------

_stackBucket=""

# lib ------------------------

stackBucketName() {
    if [[ -n "$_stackBucket" ]]; then
      echo "$_stackBucket"
      return 0
    fi

    local profile="${AWS_PROFILE:-default}"
    local region
    local accountId
    if ! region="$(aws --profile "$profile" configure get region)"; then
        gen3_log_err "aws configure get region failed"
        return 1
    fi

    if ! accountId="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"; then
        gen3_log_err "could not determine AWS account alias"
        return 1
    fi
    _stackBucket="cloudformation-${accountId}-$region"
    echo "$_stackBucket"
    return 0
}

help() {
    arun help stack
}

# 
# Apply a cloudformation update or create
#
# @param commandStr --update or --create
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
    local bucket
    local dryRun=false

    if [[ $# -lt 2 || ! $1 =~ ^-*(update|create)$ ]]; then
        gen3_log_err "apply must specify update or create"
        return 1
    fi
    while [[ "$1" =~ ^-+ ]]; do
        gen3_log_info "processing: $1"
        if [[ $1 =~ ^-*update$ ]]; then
            commandStr="update-stack"
        elif [[ "$1" =~ ^-*create$ ]]; then
            commandStr="create-stack"
        elif [[ "$1" =~ ^-*dryRun ]]; then
            dryRun=true
        fi
        shift
    done
    if [[ $# -lt 1 || ! -f "$1" ]]; then
        gen3_log_err "invalid stack path: $1"
        return 1
    fi
    stackPath="$1"
    shift
    if [[ -z "$commandStr" ]]; then
        gen3_log_err "invalid apply command, must specify --create or --update"
        return 1
    fi
    if ! templatePath="$(jq -r -e .templatePath < "$stackPath")" || ! [[ -f "$templatePath" ]]; then
        gen3_log_err "templatePath does not exist: ${templatePath}"
        return 1
    fi
    if [[ ! -f "$templatePath" ]]; then
        gen3_log_err "unable to load template $templatePath"
        return 1
    fi
    if [[ ! -f "$stackPath" || ! stackName="$(jq -r -e .StackName < "$stackPath")" ]]; then
        gen3_log_err "unable to load stackName from $stackPath"
        return 1
    fi

    s3Path="cf/$stackName/${templatePath##*/}"
    if ! bucket=$(stackBucketName); then
        gen3_log_err "failed to find cf bucket"
        return 1
    fi
    # uniquely identify the update-stack request
    reqToken="apply-$(date +%Y-%m-%d-%H-%M-%S)"

    aws cloudformation validate-template --template-body "$(cat "$templatePath")"
    aws s3 cp "$templatePath" "s3://${bucket}/$s3Path"

    skeleton="$(
        cat "$stackPath" | \
        jq -r -e --arg url "https://${bucket}.s3.amazonaws.com/${s3Path}" '.TemplateURL=$url' | \
        jq -r -e --arg token "$reqToken" '.ClientRequestToken=$token'
    )"

    local stackDir="${stackPath%/*}"
    #
    # Upload the lambda code package to S3, and
    # set the LambdaBucket and LambdaKey parameters
    #
    if [[ -d "${stackDir}/code" ]]; then
        gen3_log_info "uploading stack code/ to s3"
        local s3CodePath
        if ! s3CodePath="$(arun lambda upload)"; then
            gen3_log_err "failed to stage code/ to s3"
            return 1
        fi
        skeleton="$(
            clean="${s3CodePath#s3://}"
            bucket="${clean%%/*}"
            key="/${clean#*/}"
            jq -r --arg lambdaKey "${key}" --arg lambdaBucket "${bucket}" '.Parameters += [{ "ParameterKey": "LambdaBucket", "ParameterValue": $bucket }, { "ParameterKey": "LambdaKey", "ParameterValue": $key } ]' <<<"$skeleton"
            )"
    fi
    if [[ "$commandStr" == "update-stack" ]]; then
        if ! skeleton="$(echo "$skeleton" | jq -r -e 'del(.TimeoutInMinutes) | del(.EnableTerminationProtection)')"; then
            gen3_log_err "failed to process $skeleton"
            return 1
        fi
    fi
    cat - 1>&2 <<EOM
INFO: attempting to update stack:
$skeleton
EOM
    if [[ "$dryRun" != "false" ]]; then
        gen3_log_info "Dry-run not submitting stack: $stackName"
        return 0
    elif aws cloudformation "${commandStr}" --cli-input-json "$skeleton"; then
        gen3_log_info "Successfully submitted stack: $stackName"
        return 0
    else
        return 1
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
        stackBucketName "$@"
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
