#!/bin/bash

LITTLE_SETUP_DIR=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export LITTLE_HOME="${LITTLE_HOME:-$(cd "${LITTLE_SETUP_DIR}/.." && pwd)}"
source "${LITTLE_HOME}/lib/bash/utils.sh"

#
# arun helper - assumes AWS environment has
# been initialized as necessary
#
_doCommand() {
    local command
    command="$1"  
    if [[ -f "$LITTLE_HOME/bin/${command}.sh" ]]; then
      shift
      bash "$LITTLE_HOME/bin/${command}.sh" "$@"
    else
      "$@"
    fi
}

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
      shift
      bash "$LITTLE_HOME/bin/help.sh" "$@"
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

    local mfaSerial
    mfaSerial="$(aws --profile "$profile" configure get mfa_serial)"
    local role
    role="$(aws --profile "$profile" configure get role_arn)"
    local sourceProfile
    sourceProfile="$(aws --profile "$profile" configure get source_profile)"

    if [[ -z "$mfaSerial" && -z "$role" ]]; then
      # assume credentials are provided or available via metadata server
      _doCommand "$@"
      return $?
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
      if [[ -n "$mfaSerial" ]]; then
        read -p "Enter MFA token code for $mfaSerial: " -r code
        if [[ -z "$code" ]]; then
          return 1
        fi
      fi
      if [[ -n "$role" ]]; then
        if [[ -z "$sourceProfile" ]]; then
          # assume metadata-service credential source
          if ! aws --profile "$sourceProfile" --output json sts assume-role --role-arn "$role" --role-session "$USER" > "$cacheFile"; then
            return 1
          fi
        elif [[ -n "$mfaSerial" ]]; then
          # aws cli is smart enough to determine the mfa serial no ...
          if ! aws --profile "$sourceProfile" --output json sts assume-role --role-arn "$role" --role-session "$USER" --serial-number "$mfaSerial" --token-code "$code" > "$cacheFile"; then
            return 1
          fi
        else
          gen3_log_err "MFA required if credential source is a local profile"
          return 1
        fi
      elif [[ -n "$mfaSerial" ]]; then
        if ! aws --profile "$profile" --output json sts get-session-token --serial-number "$mfaSerial" --token-code "$code" > "$cacheFile"; then
          return 1
        fi
      else
        gen3_log_err "assertion failed - no role and no mfaSerial should have run earlier"
        return 1
      fi
    fi
    (
        export AWS_ACCESS_KEY_ID="$(jq -r .Credentials.AccessKeyId < "$cacheFile")"
        export AWS_SECRET_ACCESS_KEY="$(jq -r .Credentials.SecretAccessKey < "$cacheFile")"
        export AWS_SESSION_TOKEN="$(jq -r .Credentials.SessionToken < "$cacheFile")"
        export AWS_CACHE_FILE="$cacheFile"
        export AWS_TOKEN_EXPIRATION="$expiration"
        
        _doCommand "$@"
    )
    return $?
}

arun "$@"
