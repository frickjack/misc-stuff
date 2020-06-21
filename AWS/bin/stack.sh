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
    little help stack
}

getChangeSetName() {
    local changeSetName="little-${USER}-${HOSTNAME}"
    changeSetName="${changeSetName//[._ ]/-}"
    echo "$changeSetName"
}

#
# Extract nunjucks variables from a stackParams.json.
# Also assemble openapi from template folder.
#
# @param stackPath or - to read stdin
# @return echo nunjucks variables json
#
getStackVariables() {
    local stackPath
    local bucket="$(stackBucketName)"
    local openapi="{}"

    if [[ $# -lt 1 ]]; then
        # just output empty variable set
        cat - <<EOM
{
  "stackParameters": {},
  "stackTags": {},
  "stackTagsStr":"", 
  "stackVariables": {},
  "stackBucket": "$bucket",
  "templateFiles": {
      "openapi": "$openapi"
  }
}
EOM
        return 0
    fi
    stackPath="$1"
    shift
    local templatePath
    if templatePath="${LITTLE_HOME}/$(jq -r -e .Littleware.TemplatePath < "$stackPath")" && [[ -f "$templatePath" ]]; then
        local templateFolder="$(dirname "$templatePath")"
        local openApiPath="${templateFolder}/openapi.yaml"
        if [[ ! -f "$openApiPath" ]]; then
            openApiPath="${templateFolder}/openapi.json"
        fi
        if [[ -f "$openApiPath" ]]; then
            if ! openapi="$(yq -e -r . < "$openApiPath")"; then
                gen3_log_err "failed to parse $openApiPath"
                return 1
            fi
        else
            gen3_log_info "no openapi file found in $templateFolder"
        fi
    fi

    cat "$stackPath" | jq --arg bucket "$bucket" --arg openapi "$openapi" -r '{
        "stackParameters": (.Parameters | map({ "key": .ParameterKey, "value": .ParameterValue }) | from_entries),
        "stackTags": .Tags, 
        "stackTagsStr":(.Tags | map(tostring) | join(",")), 
        "stackVariables": .Littleware.Variables,
        "stackBucket": $bucket,
        "templateFiles": {
            "openapi": $openapi
        }
}'
}

# 
# Apply a cloudformation update or create
#
# @param commandStr --update or --create or --change
# @param dryRun optional [--dryRun]
# @param stackPath path to stackParams.json file
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

    #
    # assemble nunjucks variables from the stack file, 
    # and filter the template
    #
    local filteredTemplate
    filteredTemplate="$(mktemp "${XDG_RUNTIME_DIR}/templateFilter_XXXXXX")"
    local stackVariables
    stackVariables="$(getStackVariables "$stackPath")" || return 1
    filterTemplate "$templatePath" "$stackVariables" | tee "$filteredTemplate" 1>&2
    if ! aws cloudformation validate-template --template-body "$(cat "$filteredTemplate")" > /dev/null; then
        gen3_log_err "template validation failed after filter"
        return 1
    else
        gen3_log_info "template validation ok"
    fi
    aws s3 cp "$filteredTemplate" "s3://${bucket}/$s3Path"
    rm "$filteredTemplate"
    skeleton="$(
        cat "$stackPath" | \
        jq -r -e --arg url "https://${bucket}.s3.amazonaws.com/${s3Path}" --arg token "$reqToken" '.TemplateURL=$url | .ClientRequestToken=$token | del(.Littleware)'
    )"

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

rmChange() {
    local stackPath
    local stackName
    
    if ! stackPath="$1" || [[ ! -f "$stackPath" ]] || ! stackName="$(jq -r -e .StackName < "$stackPath")"; then
        gen3_log_err "unable to load stackName from $stackPath"
        return 1
    fi
    shift
    aws cloudformation delete-change-set --change-set-name "$(getChangeSetName)" --stack-name "$stackName"
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

#
# Helper for easy CLI access
#
filterStack() {
    if [[ $# -lt 1 || ! -f "$1" ]]; then
        gen3_log_err "invalid stack path: $1"
        return 1
    fi
    local stackPath="$1"
    shift
    local templatePath
    local stackVariables
    if ! templatePath="${LITTLE_HOME}/$(jq -r -e .Littleware.TemplatePath < "$stackPath")" || ! [[ -f "$templatePath" ]]; then
        gen3_log_err "templatePath does not exist: ${templatePath}"
        return 1
    fi
    if [[ ! -f "$templatePath" ]]; then
        gen3_log_err "unable to load template $templatePath"
        return 1
    fi
    stackVariables="$(getStackVariables "$stackPath")" || return 1
    filterTemplate "$templatePath" "$stackVariables"
}

validateStack() {
    local templateStr
    templateStr="$(filterStack "$@")" || return 1
    aws cloudformation validate-template --template-body "$templateStr"
}

validateTemplate() {
    local templateStr
    templateStr="$(filterTemplate "$@")" || return 1
    aws cloudformation validate-template --template-body "$templateStr" | cat -
    return "${PIPESTATUS[0]}"
}

filterTemplate() {
    local templatePath
    local templateStr
    # initialize filterVariables with empty set
    local filterVariables="$(getStackVariables)"
    if [[ $# -lt 1 || ! -f "$1" ]]; then
      gen3_log_err "validate requires path to template: $@"
      return 1
    fi
    templatePath="$1"
    shift
    if [[ $# -gt 0 ]]; then
        filterVariables="$1"
        shift
    fi
    if ! templateStr="$(little filter "$filterVariables" < "$templatePath")"; then
      gen3_log_err "Template filter failed: $templatePath"
      return 1
    fi
    local temp
    if ! jq -e -r . <<< "$templateStr"; then
      gen3_log_err "Template failed json validation: $templateStr"
      return 1
    fi
}

resources() {
    local stackPath="$1"
    shift || return 1
    aws cloudformation describe-stack-resources --stack-name "$(jq -r .StackName < "$stackPath")"
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
    "resources")
        resources "$@"
        ;;
    "rm-change")
        rmChange "$@"
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
    "filter")
        filterStack "$@"
        ;;
    "filter-template")
        filterTemplate "$@"
        ;;
    "list")
        list "$@"
        ;;
    "variables")
        getStackVariables "$@"
        ;;
    "update")
        update "$@"
        ;;
    "validate")
        validateStack "$@"
        ;;
    "validate-template")
        validateTemplate "$@"
        ;;
    *)
        help
        ;;
esac
