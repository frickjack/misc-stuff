#!/bin/bash

LITTLE_SETUP_DIR=$(dirname "${BASH_SOURCE:-$0}")  # $0 supports zsh
export LITTLE_HOME="${LITTLE_HOME:-$(pwd)}"
source "${LITTLE_HOME}/lib/bash/utils.sh"


#
# determine what "type" a command is
#
# @param command little or platform command
# @return echo commandType binSuffix where
#     commandType is one of:
#        "little-aws" for aws commands that require AWS credentials, 
#        "little-basic" commands that do not require aws creds,
#        "not-little" for platform applications,
#        "bad-command" if it looks like a typo
#     and binSuffix is one of sh py js xx
#
littleCommandType() {
    local command
    local suffixList
    local suffix
    command="$1"
    suffixList=(sh js py)
    for suffix in "${suffixList[@]}"; do
      if [[ -f "$LITTLE_HOME/bin/${command}.${suffix}" ]]; then
        echo "little-aws" "$suffix"
        return 0
      elif [[ -f "$LITTLE_HOME/bin/basic/${command}.${suffix}" ]]; then
        echo "little-basic" "$suffix"
        return 0
      fi
    done
    if which "$command" > /dev/null 2>&1; then
      echo "not-little" "xx"
      return 0
    fi
    echo "bad-command" "xx"
    return 0
}

#
# little helper - assumes AWS environment has
# been initialized as necessary
#
littleDoCommand() {
    local command="$1"
    local commandType=($(littleCommandType "$@"))
    
    if [[ "$commandType" == "not-little" ]]; then
      "$@"
      return $?
    elif [[ "$commandType" == "bad-command" ]]; then
      gen3_log_err "unknown command: $@"
      return 1
    fi
    shift
    local tool
    local suffix="${commandType[1]}"
    local commandPath
    case "$suffix" in
      py)
        tool=python
        ;;
      js)
        tool=nodejs
        ;;
      *)
        tool=bash
        ;;
    esac
    if [[ "$commandType" == "little-aws" ]]; then
      commandPath="$LITTLE_HOME/bin/${command}.${suffix}"
    else
      commandPath="$LITTLE_HOME/bin/basic/${command}.${suffix}"
    fi
    "$tool" "$commandPath" "$@"
}

#
# Run a command with environment set with credentials
# acquired via `aws sts assume-role`
#
# @param profile optional AWS profile that specifies the role-arn
#            and mfa serial number
# @param args ... rest of the command to run
#
littleRun() {
    if [[ $# -lt 1 || "$1" =~ ^-*help$ ]]; then
      shift
      littleDoCommand help "$@"
      return $?
    fi
    local commandType=($(littleCommandType "$@"))

    if [[ "$commandType" == "bad-command" ]]; then
      gen3_log_err "unknown command: $@"
      return 1
    fi
    if [[ $# -gt 1 && "$2" =~ ^-*help$ && ("$commandType" == "little-aws" || "$commandType" == "little-basic") ]]; then
      littleDoCommand help "$@"
      return $?
    fi
    if [[ "$commandType" == "little-basic" ]]; then
      # no need for AWS creds, just go
      littleDoCommand "$@"
      return $?
    fi
    # setup AWS creds env variables
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
      littleDoCommand "$@"
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
        
        littleDoCommand "$@"
    )
    return $?
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  littleRun "$@"
fi
