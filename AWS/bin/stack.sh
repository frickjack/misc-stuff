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

getChangeSetName() {
    local changeSetName="little-${USER}-${HOSTNAME}"
    changeSetName="${changeSetName//[._ ]/-}"
    echo "$changeSetName"
}

# 
# Apply a cloudformation update or create
#
# @param commandStr --update or --create or --change
# @param dryRun optional [--dryRun]
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
    local changeSetName="$(getChangeSetName)"

    if [[ $# -lt 2 || ! $1 =~ ^-*(update|create|changeset)$ ]]; then
        gen3_log_err "apply must specify update or create or changeset"
        return 1
    fi
    if [[ $1 =~ ^-*update$ ]]; then
        commandStr="update-stack"
    elif [[ "$1" =~ ^-*create$ ]]; then
        commandStr="create-stack"
    elif [[ "$1" =~ ^-*changeset$ ]]; then
        commandStr="create-change-set"
    else
        gen3_log_err "invalid command $1"
        return 1
    fi
    shift

    while [[ $# -gt 0 && "$1" =~ ^-+ ]]; do
        gen3_log_info "processing: $1"
        if [[ "$1" =~ ^-*dryRun ]]; then
            dryRun=true
        else
            gen3_log_warn "ignoring unknown flag $1"
        fi
        shift
    done
    if [[ $# -lt 1 || ! -f "$1" ]]; then
        gen3_log_err "invalid stack path: $1"
        return 1
    fi
    stackPath="$1"
    shift
    if ! templatePath="${LITTLE_HOME}/$(jq -r -e .Littleware.TemplatePath < "$stackPath")" || ! [[ -f "$templatePath" ]]; then
        gen3_log_err "templatePath does not exist: ${templatePath}"
        return 1
    fi
    if [[ ! -f "$templatePath" ]]; then
        gen3_log_err "unable to load template $templatePath"
        return 1
    fi
    if [[ ! -f "$stackPath" ]] || ! stackName="$(jq -r -e .StackName < "$stackPath")"; then
        gen3_log_err "unable to load stackName from $stackPath"
        return 1
    fi
    gen3_log_info "Got stack name: $stackName"

    s3Path="cf/$stackName/${templatePath##*/}"
    if ! bucket=$(stackBucketName); then
        gen3_log_err "failed to find cf bucket"
        return 1
    fi
    # uniquely identify the update-stack request
    reqToken="apply-$(date +%Y-%m-%d-%H-%M-%S)"

    if ! aws cloudformation validate-template --template-body "$(cat "$templatePath")"; then
        gen3_log_err "template validation failed"
        return 1
    else
        gen3_log_info "template validation ok"
    fi
    local filteredTemplate
    filteredTemplate="$(mktemp "${XDG_RUNTIME_DIR}/templateFilter_XXXXXX")"
    filterTemplate "$templatePath" | tee "$filteredTemplate" 1>&2
    aws s3 cp "$filteredTemplate" "s3://${bucket}/$s3Path"
    rm "$filteredTemplate"
    skeleton="$(
        cat "$stackPath" | \
        jq -r -e --arg url "https://${bucket}.s3.amazonaws.com/${s3Path}" '.TemplateURL=$url' | \
        jq -r -e --arg token "$reqToken" '.ClientRequestToken=$token' | \
        jq -r -e 'del(.Littleware)'
    )"

    local stackDir="$(dirname "$stackPath")"
    #
    # Upload the lambda code package to S3, and
    # set the LambdaBucket and LambdaKey parameters
    #
    if [[ -d "${stackDir}/code" ]]; then
        gen3_log_info "uploading stack code/ to s3"
        local s3CodePath
        if ! s3CodePath="$(arun lambda upload "${stackDir}/code")"; then
            gen3_log_err "failed to stage code/ to s3"
            return 1
        fi
        skeleton="$(
            clean="${s3CodePath#s3://}"
            bucket="${clean%%/*}"
            key="${clean#*/}"
            jq -r --arg key "${key}" --arg bucket "${bucket}" '.Parameters += [{ "ParameterKey": "LambdaBucket", "ParameterValue": $bucket }, { "ParameterKey": "LambdaKey", "ParameterValue": $key } ]' <<<"$skeleton"
            )"
    fi
    if [[ "$commandStr" != "create-stack" ]]; then
        if ! skeleton="$(jq -r -e 'del(.TimeoutInMinutes) | del(.EnableTerminationProtection)' <<< "$skeleton")"; then
            gen3_log_err "failed to process $skeleton"
            return 1
        fi
    fi
    if [[ "$commandStr" == "create-change-set" ]]; then
        if ! skeleton="$(jq -r -e --arg name "${changeSetName}" '.ClientToken = .ClientRequestToken | .ChangeSetName = $name | .ChangeSetType = "UPDATE" | del(.ClientRequestToken)' <<< "$skeleton")"; then
            gen3_log_err "failed to set ClientToken for $skeleton"
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

makeChange() {
    apply --changeset "$@"
}

showChange() {
    local stackPath
    local stackName
    
    if ! stackPath="$1" || [[ ! -f "$stackPath" ]] || ! stackName="$(jq -r -e .StackName < "$stackPath")"; then
        gen3_log_err "unable to load stackName from $stackPath"
        return 1
    fi
    shift
    aws cloudformation describe-change-set --change-set-name "$(getChangeSetName)" --stack-name "$stackName"
}

describeStack() {
    local stackPath
    local stackName
    
    if ! stackPath="$1" || [[ ! -f "$stackPath" ]] || ! stackName="$(jq -r -e .StackName < "$stackPath")"; then
        gen3_log_err "unable to load stackName from $stackPath"
        return 1
    fi
    shift
    aws cloudformation describe-stacks --stack-name "${stackName}"
}

executeChange() {
    local stackPath
    local stackName
    
    if ! stackPath="$1" || [[ ! -f "$stackPath" ]] || ! stackName="$(jq -r -e .StackName < "$stackPath")"; then
        gen3_log_err "unable to load stackName from $stackPath"
        return 1
    fi
    shift
    aws cloudformation execute-change-set --change-set-name "$(getChangeSetName)" --stack-name "$stackName"
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
    aws cloudformation describe-stack-events --stack-name "$stackName" --max-items 100
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

validateTemplate() {
    local templateStr
    templateStr="$(filterTemplate "$@")"
    aws cloudformation validate-template --template-body "$templateStr"
}

filterTemplate() {
    local templateFolder
    local templatePath
    local templateStr
    if [[ $# -lt 1 || ! -f "$1" ]]; then
      gen3_log_err "validate requires path to template: $@"
      return 1
    fi
    templatePath="$1"
    shift
    templateFolder="$(dirname "$templatePath")"
    if ! templateStr="$(jq -e -r . < "$templatePath")"; then
      gen3_log_err "Template failed json validation: $templatePath"
      return 1
    fi
    local openapi="{}"
    if [[ -f "${templateFolder}/openapi.yaml" ]]; then
        if ! openapi="$(yq -e -r . < "${templateFolder}/openapi.yaml")"; then
          gen3_log_err "failed to parse ${templateFolder}/openapi.yaml"
          return 1
        fi
    elif [[ -f "${templateFolder}/openapi.json" ]]; then
        if ! openapi="$(jq -e -r . < "${templateFolder}/openapi.json")"; then
          gen3_log_err "failed to parse ${templateFolder}/openapi.json"
          return 1
        fi
    else
        gen3_log_info "no openapi file found in $templateFolder"
    fi
    jq -e --argjson openapi "${openapi}" -r '.Resources=(.Resources | map_values(if .Type == "AWS::ApiGateway::RestApi" then .Properties.Body=$openapi else . end))' <<< "$templateStr"
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
    "change-name")
        getChangeSetName "$@"
        ;;
    "make-change")
        makeChange "$@"
        ;;
    "show-change")
        showChange "$@"
        ;;
    "exec-change")
        executeChange "$@"
        ;;
    "create")
        create "$@"
        ;;
    "describe")
        describeStack "$@"
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
    "validate-template")
        validateTemplate "$@"
        ;;
    "filter-template")
        filterTemplate "$@"
        ;;
    *)
        help
        ;;
esac
