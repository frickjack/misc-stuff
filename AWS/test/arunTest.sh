
test_arun_env() {
    (unset AWS_SESSION_TOKEN; arun env | grep AWS_SESSION_TOKEN > /dev/null 2>&1); because $? "arun sets the AWS_SESSION_TOKEN environment"
}


shunit_runtest "test_arun_env" "local,arun"
