#!/bin/bash

#
# Rotate the access key associated with the
# default AWS profile, and output a new ~/.aws/credentials
# file
#
rotateMyKey() {
  if [[ "default" != "${AWS_PROFILE:-default}" ]]; then
    echo "ERROR: rotateMyKey only runs on the 'default' AWS_PROFILE, not $AWS_PROFILE" 1>&2
    return 1
  fi
  local activeKey
  activeKey="$(aws configure get aws_access_key_id)"
  if [[ -z "$activeKey" ]]; then
    echo "ERROR: unable to determine active key for default profile" 1>&2
    return 1
  fi
  local keyData
  keyData="$(aws iam list-access-keys)"
  local extraKeys
  extraKeys="$(echo "$keyData" | jq -r  --arg activeKey "$activeKey" '.AccessKeyMetadata | map(select(.AccessKeyId!=$activeKey))|map(.AccessKeyId)|.[]' | head -1)"
  if [[ -n "$extraKeys" ]]; then
    echo -e "ERROR: user already has multiple keys - delete one you're not using - ex:" 1>&2
    echo -e "    arun aws iam delete-access-key --access-key-id '$extraKeys'" 1>&2
    return 1
  fi
  local newKeyData
  if newKeyData="$(aws iam create-access-key)"; then
    local credsFile
    credsFile="$HOME/.aws/credentials"
    if [[ -f "$credsFile" ]]; then
      mv "$credsFile" "${credsFile}.bak"
    fi
    echo "Generating new creds file $credsFile" 1>&2
    cat - > "$HOME/.aws/credentials" <<EOM
[default]
aws_secret_access_key = $(echo "$newKeyData" | jq -r .AccessKey.SecretAccessKey)
aws_access_key_id = $(echo "$newKeyData" | jq -r .AccessKey.AccessKeyId)
EOM
    echo "Deleting old access key" 1>&2
    aws iam delete-access-key --access-key-id "$activeKey" 1>&2
    return $?
  else
    echo "ERROR: failed to create new access key" 1>&2
    return 1
  fi
  return 2
}


if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  rotateMyKey "$@"
fi
