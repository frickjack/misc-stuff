
testArunEnv() {
    (! aws configure get role_arn) || (unset AWS_SESSION_TOKEN; arun env | grep AWS_SESSION_TOKEN > /dev/null 2>&1); because $? "arun sets the AWS_SESSION_TOKEN environment"
}


shunit_runtest "testArunEnv" "local,arun"
