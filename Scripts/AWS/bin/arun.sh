
#
# Run a command with environment set with credentials
# acquired via `aws sts assume-role`
#
# @param profile AWS profile that specifies the role-arn
#            and mfa serial number
# @param args ... rest of the command to run
#
arun() {
    if [[ $# -lt 2 ]]; then
      echo "Use: arun PROFILE command ..."
      return 1
    fi
    local profile
    local cacheFile
    profile="$1"
    shift
    cacheFile="$XDG_RUNTIME_DIR/profile_${profile}.json"
    if [[ -f "$cacheFile" ]]; then
      local expiration
      local now
      expiration="$(jq -r .Credentials.Expiration < "$cacheFile")"
      expiration="$(date "-d$expiration" '+%s')"
      now="$(date '+%s')"
      if [[ "$expiration" -lt "$((now  + 300))" ]]; then
        /bin/rm "$cacheFile"
      fi
    else
      expiration="$(jq -r .Credentials.Expiration < "$cacheFile")"
    fi
    if [[ ! -f "$cacheFile" ]]; then
      # need to refresh the cache if we make it here
      local code
      read -p 'Enter MFA token code: ' -r code
      if [[ -z "$code" ]]; then
        return 1
      fi
      aws --output json sts assume-role --role-arn $(aws --profile "$profile" configure get role_arn) --role-session reuben --serial-number $(aws --profile "$profile" configure get mfa_serial) --token-code "$code" > "$cacheFile"
    fi
    (
        export AWS_ACCESS_KEY_ID="$(jq -r .Credentials.AccessKeyId < "$cacheFile")"
        export AWS_SECRET_ACCESS_KEY="$(jq -r .Credentials.SecretAccessKey < "$cacheFile")"
        export AWS_SESSION_TOKEN="$(jq -r .Credentials.SessionToken < "$cacheFile")"
        export AWS_CACHE_FILE="$cacheFile"
        export AWS_TOKEN_EXPIRATION="$expiration"
        "$@"
    )
    return $?
}

if [[ -z "$GEN3_SOURCE_ONLY" ]]; then
  arun "$@"
fi
