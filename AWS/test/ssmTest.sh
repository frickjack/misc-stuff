
#
# Setup and delete secret
#
testParameterPut() {
    if [[ -n "$CODEBUILD_SRC_DIR" ]]; then
      gen3_log_info "skipping testParameterPut in CODEBUILD environment"
      return 0
    fi
    local secretName="applications.tools.cell0.test.test-param"
    if secretInfo="$(aws ssm get-parameter --name "$secretName")"; then
      gen3_log_info "setup: deleting parameter from previous test: $secretInfo"
      aws ssm delete-parameter --name "$secretName"
      sleep 1
    fi
    local value='{ "time": '$(date +%s)' }'
    jq -e -r . <<<"$value"; because $? "test secret is valid json: $value"
    secretInfo="$(little ssm put-parameter $secretName "$value" 'test secret')"; because $? "create ssm param worked $secretInfo"
    local secretValue
    secretValue="$(aws ssm get-parameter --name "$secretName" --with-decryption | jq -e -r .Parameter.Value)"; because $? "can retrieve the secret value: $secretValue"
    [[ "$secretValue" == "$value" ]]; because $? "the saved secret has the submitted value: $value ?= $secretValue"

    # test update
    value='{ "time": '$(date +%s)', "version": 2 }'
    jq -e -r . <<<"$value"; because $? "test secret v2 is valid json: $value"
    secretInfo="$(little ssm put-parameter $secretName "$value" 'test secret')"; because $? "create ssm param worked $secretInfo"
    local secretValue
    secretValue="$(aws ssm get-parameter --name "$secretName" --with-decryption | jq -e -r .Parameter.Value)"; because $? "can retrieve the secret value: $secretValue"
    [[ "$secretValue" == "$value" ]]; because $? "the saved secret has the submitted value: $value ?= $secretValue"
    
    aws ssm delete-parameter --name "$secretName"; because $? "delete-parameter should work ok: $secretName"
}

shunit_runtest "testParameterPut" "ssm"
