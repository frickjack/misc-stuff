#!/bin/bash

source "${LITTLE_HOME}/lib/bash/utils.sh"

# lib ----------

#
# Rotate the access key associated with the
# default AWS profile, and output a new ~/.aws/credentials
# file
#
rotateMyKey() {
  local credsFile
  credsFile="$HOME/.aws/credentials"
  
  if [[ "default" != "${AWS_PROFILE:-default}" ]]; then
    gen3_log_err "rotateMyKey only runs on the 'default' AWS_PROFILE, not $AWS_PROFILE"
    return 1
  fi
  if !([[ -f "$credsFile" ]] && grep '\[default\]' "$credsFile" > /dev/null 2>&1); then
    gen3_log_err "rotateMyKey requires ~/.aws/credentials to exist with a default profile"
    return 1
  fi
  local activeKey
  activeKey="$(aws configure get aws_access_key_id)"
  if [[ -z "$activeKey" ]]; then
    gen3_log_err "unable to determine active key for default profile"
    return 1
  fi
  local keyData
  keyData="$(aws iam list-access-keys)"
  local extraKeys
  extraKeys="$(echo "$keyData" | jq -r  --arg activeKey "$activeKey" '.AccessKeyMetadata | map(select(.AccessKeyId!=$activeKey))|map(.AccessKeyId)|.[]' | head -1)"
  if [[ -n "$extraKeys" ]]; then
    gen3_log_err "user already has multiple keys - delete one you're not using - ex:"
    gen3_log_err "    arun aws iam delete-access-key --access-key-id '$extraKeys'"
    return 1
  fi
  local newKeyData
  if newKeyData="$(aws iam create-access-key)"; then
    if [[ -f "$credsFile" ]]; then
      mv "$credsFile" "${credsFile}.bak"
    else
      touch "${credsFile}.bak"
    fi
    gen3_log_info "Generating new creds file $credsFile"
    sed 's/default/default-old/g' "${credsFile}.bak" > "${credsFile}"
    cat - >> "$HOME/.aws/credentials" <<EOM
[default]
aws_secret_access_key = $(echo "$newKeyData" | jq -r .AccessKey.SecretAccessKey)
aws_access_key_id = $(echo "$newKeyData" | jq -r .AccessKey.AccessKeyId)
EOM
    chmod 0400 "$credsFile" "${credsFile}.bak"
    echo "Deleting old access key" 1>&2
    aws iam delete-access-key --access-key-id "$activeKey" 1>&2
    return $?
  else
    echo "ERROR: failed to create new access key" 1>&2
    return 1
  fi
  return 2
}


# main -------------

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  rotateMyKey "$@"
fi
