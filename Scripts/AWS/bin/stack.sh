#!/bin/bash


set -e

# globals -------------------

if ! region="$(aws --profile "$profile" configure get region)"; then
    echo "ERROR: aws configure get region failed" 1>&2
    return 1
fi

bucket="cloudformation-frickjack-$region"
accountId="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"

# lib ------------------------

help() {
    echo "Use: bash stack.sh bucket|create|delete|events path/to/template" 1>&2
}

# 
# Apply a cloudformation update or create
#
# @param commandStr --update or --create
#
apply() {
    local reqToken
    local skeleton
    local commandStr
    local path
    local stackName
    local s3Path

    if [[ $# -lt 3 || ! $1 =~ ^-*(update|create)$ ]]; then
      echo "ERROR: apply must specify update or create" 1>&2
      return 1
    fi
    if [[ $1 =~ ^-*update$ ]]; then
      commandStr="update-stack"
    else
      commandStr="create-stack"
    fi
    shift
    path="$1"
    shift
    stackName="$1"
    shift
    s3Path="cf/$stackName/${path##*/}"
   
    # uniquely identify the update-stack request
    reqToken="apply-$(date +%Y-%m-%d-%H-%M-%S)"

    aws cloudformation validate-template --template-body "$(cat "$path")"
    aws s3 cp "$path" "s3://${bucket}/$s3Path"

    skeleton="$(
        cat - <<EOM
{
    "StackName": "$stackName",
    "TemplateURL": "https://${bucket}.s3.amazonaws.com/${s3Path}",
    $(if [[ "$commandStr" == "create-stack" ]]; then 
        echo '"TimeoutInMinutes": 5,'
        echo '"EnableTerminationProtection": true,'
      fi)
    "Capabilities": [
        "CAPABILITY_NAMED_IAM"
    ],
    "StackPolicyBody": "{\"Statement\" : [{\"Effect\" : \"Allow\", \"Action\" : \"Update:*\", \"Principal\": \"*\", \"Resource\" : \"*\"}]}",
    "Tags": [
            {
                "Key": "org",
                "Value": "devops"
            },
            {
                "Key": "project",
                "Value": "infrastructure"
            },
            {
                "Key": "stack",
                "Value": "main"
            },
            {
                "Key": "stage",
                "Value": "prod"
            },
            {
              "Key": "role",
              "Value": "authz-general"
            }
    ],
    "ClientRequestToken": "$reqToken"
}

EOM
    )"

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
    #aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name "$stackName"
    aws cloudformation delete-stack --stack-name "$stackName"
}

#
# Generate a stack name from a json/yaml template path
#
pathToStack() {
    local path
    local base
    if [[ $# -lt 1 ]]; then
      echo "ERROR: pathToStack takes a path" 1>&2
      return 1
    fi
    path="$1"
    shift
    base="${path##*/}"   # get basename
    base="${base%.*}"    # remove .json/.yaml
    base="${base,[A-Z]}" # first character lower case
    echo "little-account-${base}-${accountId}"
}

# main -----------------

if [[ $# -lt 1 || $1 =~ ^-*h(elp)?$ ]]; then
  help
  exit 1
fi

command="$1"
shift

if [[ "$command" != "bucket" ]]; then
    path="$1"
    shift

    if [[ -z "$path" || ! -f "$path" ]]; then
        echo "ERROR: run apply.sh within the accounSetup/ folder" 1>&2
        exit 1
    fi

    stackName="$(pathToStack "$path")"
fi

case "$command" in
    "bucket")
        echo "$bucket"
        ;;
    "create")
        create "$path" "$stackName"
        ;;
    "delete")
        delete "$path" "$stackName"
        ;;
    "events")
        aws cloudformation describe-stack-events --stack-name "$stackName"
        ;;
    "update")
        update "$path" "$stackName"
        ;;
    *)
        help
        ;;
esac
