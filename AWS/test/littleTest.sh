
testLittleEnv() {
    (! aws configure get role_arn) || (unset AWS_SESSION_TOKEN; little env | grep AWS_SESSION_TOKEN > /dev/null 2>&1); because $? "little sets the AWS_SESSION_TOKEN environment"
}

testLittleCommandType() {
    gen3_load little
    local comType=($(littleCommandType markdown))
    [[ "$comType" == "little-basic" ]]; because $? "markdown is a basic command: $comType ?= little-basic"
    comType=($(littleCommandType lambda))
    [[ "$comType" == "little-aws" ]]; because $? "lambda is an aws command: $comType ?= little-aws"
}

shunit_runtest "testLittleEnv" "local,little"
shunit_runtest "testLittleCommandType" "local,little"
