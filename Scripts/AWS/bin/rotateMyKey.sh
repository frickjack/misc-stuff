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
    echo -e "    aws delete-access-key --access-key-id '$extraKeys'" 1>&2
    return 1
  fi
  echo $keyData | jq -r .

  return $?
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  rotateMyKey "$@"
fi
