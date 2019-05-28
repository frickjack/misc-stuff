#!/bin/bash


if [[ ! -f "./IamSetup.json" ]]; then
    echo "ERROR: run apply.sh within the accounSetup/ folder" 1>&2
    exit 1
fi

set -e
if ! region="$(aws --profile "$profile" configure get region)"; then
    echo "ERROR: aws configure get region failed" 1>&2
    return 1
fi

bucket="cloudformation-frickjack-$region"
accountId="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"
stackName="little-account-iamSetup-${accountId}"

help() {
    echo "Use: bash stack.sh create|delete|events" 1>&2
}

if [[ $# -lt 1 || $1 =~ ^-*h(elp)?$ ]]; then
  help
  exit 1
fi

create() {
    local reqToken
    local skeleton

    # uniquely identify the update-stack request
    reqToken="apply-$(date +%Y-%m-%d-%H-%M-%S)"

    aws cloudformation validate-template --template-body "$(cat IamSetup.json)"
    aws s3 sync ../accountSetup "s3://${bucket}/accountSetup/"

    skeleton="$(
        cat - <<EOM
{
    "StackName": "$stackName",
    "TemplateURL": "https://${bucket}.s3.amazonaws.com/accountSetup/IamSetup.json",
    "TimeoutInMinutes": 5,
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
    "ClientRequestToken": "$reqToken",
    "EnableTerminationProtection": true
}

EOM
    )"

    cat - 1>&2 <<EOM
INFO: attempting to update stack:
$skeleton
EOM
    if aws cloudformation create-stack --cli-input-json "$skeleton"; then
    echo "INFO: Successfully submitted stack: $stackName" 1>&2
    fi
}

delete() {
    aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name "$stackName"
    aws cloudformation delete-stack --stack-name "$stackName"
}

command="$1"
shift
case "$command" in
    "create")
        create "$@"
        ;;
    "delete")
        delete "$@"
        ;;
    "events")
        aws cloudformation describe-stack-events --stack-name "$stackName"
        ;;
    *)
        help
        ;;
esac
