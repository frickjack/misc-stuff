testStackValidate() {
  local templates
  local path
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml')"
  for path in $templates; do
    arun stack validate "$path"; because $? "this is a valid template: $path"
  done
}

testStackBucketName() {
  local bucket
  bucket=$(arun stack bucket) && [[ "$bucket" =~ ^cloudformation-.+ ]];
    because $? "arun stack bucket looks like cloudformation-account-region"
}

testStackCreate() {
  arun stack create --dryRun "${LITTLE_HOME}/db/cloudformation/frickjack/accountSetup/snsNotify/stackParams.json";
    because $? "stack create --dryRun should run ok"
}


shunit_runtest "testStackBucketName" "stack"
shunit_runtest "testStackCreate" "stack"
shunit_runtest "testStackValidate" "stack"
