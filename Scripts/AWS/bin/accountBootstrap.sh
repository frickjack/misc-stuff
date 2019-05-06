#!/bin/bash

# lib -----------------------

#
# Bootstraps a new AWS region:to get it into
# a state ready to run cloud-formation bootstrap/
#
# * cloudformation bucket in the region 
#
aboot() {
  if [[ -z "$AWS_PROFILE" ]]; then
    echo -e "ERROR: AWS_PROFILE not set"
    return 1
  fi
  (    
    set -e
    local bucket
    local account
    local region
    account="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"
    if ! region="$(aws configure get region)"; then
      echo "ERROR: aws configure get region failed" 1>&2
      return 1
    fi
    bucket="cloudformation-${account//[ _,]/-}-${region}"

    aws s3api create-bucket --cli-input-json "$(cat - <<EOM
      {
        "ACL": "private",
        "Bucket": "${bucket}",
        "CreateBucketConfiguration": {
            "LocationConstraint": "$(aws configure get region)"
        },
        "GrantFullControl": "",
        "GrantRead": "",
        "GrantReadACP": "",
        "GrantWrite": "",
        "GrantWriteACP": ""
      }
EOM
    )" 1>&2;

    aws s3api put-bucket-encryption --cli-input-json "$(cat - <<EOM
    {
      "Bucket": "$bucket",
      "ServerSideEncryptionConfiguration": {
          "Rules": [
              {
                  "ApplyServerSideEncryptionByDefault": {
                      "SSEAlgorithm": "AES256"
                  }
              }
          ]
      }
    }
EOM
    )" 1>&2

    aws s3api put-bucket-tagging --cli-input-json "$(cat - <<EOM
{
    "Bucket": "$bucket",
    "Tagging": {
        "TagSet": [
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
              "Value": "cloudformation-bucket"
            }
        ]
    }
}
EOM
    )" 1>&2
    echo $bucket
  )
}

# main -------------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  aboot "$@"
fi