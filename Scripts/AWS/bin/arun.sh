#!/bin/bash

LITTLE_SETUP_DIR=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
LITTLE_HOME="${LITTLE_HOME:-$(cd "${LITTLE_SETUP_DIR}/.." && pwd)}"


#
# Run a command with environment set with credentials
# acquired via `aws sts assume-role`
#
# @param profile optional AWS profile that specifies the role-arn
#            and mfa serial number
# @param args ... rest of the command to run
#
arun() {
    if [[ $# -lt 1 || "$1" =~ ^-*help$ ]]; then
      bash "$LITTLE_HOME/bin/help.sh"
      return 1
    fi
    if [[ "$1" == "profiles" ]]; then
      cat ~/.aws/config | grep '\[' | sed -E 's/\[(profile )?//g' | sed 's/]//g'
      return 0
    fi

    local profile
    profile="${AWS_PROFILE:-default}"
    local cacheFile
    cacheFile="$XDG_RUNTIME_DIR/profile_${profile}.json"
    if [[ $# -gt 1 && "$1" =~ ^--*profile$ ]]; then
      shift
      profile="$1"
      shift
    fi

    local region
    if ! region="$(aws --profile "$profile" configure get region)"; then
      echo "ERROR: aws configure get region failed" 1>&2
      return 1
    fi

    local cacheFile
    cacheFile="$XDG_RUNTIME_DIR/profile_${profile}.json"
    if [[ -f "$cacheFile" ]]; then
      local expiration
      local now
      expiration="$(jq -e -r .Credentials.Expiration < "$cacheFile")"
      if [[ -n "$expiration" ]]; then
        expiration="$(date "-d$expiration" '+%s')"
      fi
      now="$(date '+%s')"
      if [[ "$expiration" -lt "$((now  + 300))" ]]; then
        /bin/rm "$cacheFile"
      fi
    fi

    if [[ ! -f "$cacheFile" ]]; then
      # need to refresh the cache if we make it here
      local code
      read -p 'Enter MFA token code: ' -r code
      if [[ -z "$code" ]]; then
        return 1
      fi
      local role
      role="$(aws --profile "$profile" configure get role_arn)"
      local mfaSerial
      mfaSerial="$(aws --profile "$profile" configure get mfa_serial)"
      if [[ -n "$role" ]]; then
        local sourceProfile
        sourceProfile="$(aws --profile "$profile" configure get source_profile)"
        if [[ -z "$sourceProfile" ]]; then
          echo "ERROR: no source_profile setting in aws config for $profile" 1>&2
          return 1
        fi
        if ! aws --profile "$sourceProfile" --output json sts assume-role --role-arn "$role" --role-session "$USER" --serial-number "$mfaSerial" --token-code "$code" > "$cacheFile"; then
          return 1
        fi
      else
        if ! aws --profile "$profile" --output json sts get-session-token --serial-number "$mfaSerial" --token-code "$code" > "$cacheFile"; then
          return 1
        fi
      fi
    fi
    (
        export AWS_ACCESS_KEY_ID="$(jq -r .Credentials.AccessKeyId < "$cacheFile")"
        export AWS_SECRET_ACCESS_KEY="$(jq -r .Credentials.SecretAccessKey < "$cacheFile")"
        export AWS_SESSION_TOKEN="$(jq -r .Credentials.SessionToken < "$cacheFile")"
        export AWS_CACHE_FILE="$cacheFile"
        export AWS_TOKEN_EXPIRATION="$expiration"
        
        local command
        command="$1"  
        if [[ -f "$LITTLE_HOME/bin/${command}.sh" ]]; then
          shift
          bash "$LITTLE_HOME/bin/${command}.sh" "$@"
        else
          "$@"
        fi
    )
    return $?
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  arun "$@"
fi
