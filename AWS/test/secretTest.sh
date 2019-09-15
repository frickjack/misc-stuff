
#
# Setup and delete secret
#
testSecretCreate() {
    local secretName="applications/little/cell0/test/test-secret"
    local secretId
    if secretInfo="$(arun secret lookup $secretName)"; then
      aws secretsmanager delete-secret --secret-id "$(jq -r .ARN <<<"$secretInfo")"
    fi
    local value="$(date +%s)"
    secretInfo="$(arun secret create $secretName $value 'test secret')"; because $? "create secret worked $secretInfo"
    local secretId
    secretId="$(jq -e -r .ARN <<<"$secretInfo")"; because $? "secretInfo should include secret id: $secretId"
    aws secretsmanager delete-secret --secret-id "$secretId"; because $? "delete-secret should work ok: $secretId"
}

shunit_runtest "testSecretCreate" "secret"
