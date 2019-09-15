
#
# Setup and delete secret
#
testSecretCreate() {
    local secretName="applications/tools/cell0/test/test-secret"
    local secretId
    if secretInfo="$(arun secret lookup $secretName)"; then
      gen3_log_info "setup: deleting secret from previous test: $secretInfo"
      aws secretsmanager delete-secret --secret-id "$(jq -r .ARN <<<"$secretInfo")" --force-delete-without-recovery
      sleep 1
    fi
    local value='{ "time": '$(date +%s)' }'
    jq -e -r <<<"$value"; because $? "test secret is valid json: $value"
    secretInfo="$(arun secret create $secretName "$value" 'test secret')"; because $? "create secret worked $secretInfo"
    local secretId
    secretId="$(jq -e -r .ARN <<<"$secretInfo")"; because $? "secretInfo should include secret id: $secretId"
    local secretValue
    secretValue="$(aws secretsmanager get-secret-value --secret-id "$secretId")" && secretValue="$(jq -e -r '.SecretString' <<<"$secretValue")"; because $? "can retrieve the secret value"
    [[ "$secretValue" == "$value" ]]; because $? "the saved secret has the submitted value: $value ?= $secretValue"
    aws secretsmanager delete-secret --secret-id "$secretId" --force-delete-without-recovery; because $? "delete-secret should work ok: $secretId"
}

shunit_runtest "testSecretCreate" "secret"
