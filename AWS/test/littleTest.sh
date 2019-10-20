
testLittleEnv() {
    (! aws configure get role_arn) || (unset AWS_SESSION_TOKEN; little env | grep AWS_SESSION_TOKEN > /dev/null 2>&1); because $? "little sets the AWS_SESSION_TOKEN environment"
}


shunit_runtest "testLittleEnv" "local,little"
