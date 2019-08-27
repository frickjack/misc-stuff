testStackValidate() {
  local templates
  local path
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml' | grep -v openapi | grep -v petstore)"
  for path in $templates; do
    arun stack validate-template "$path"; because $? "this is a valid template: $path"
  done
}

testStackFilter() {
  local templates
  local path
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml'  | grep -v openapi | grep -v petstore)"
  for path in $templates; do
    arun stack filter-template "$path" | jq -e -r . > /dev/null; because $? "filter template works for: $path"
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
shunit_runtest "testStackFilter" "stack"
shunit_runtest "testStackValidate" "stack"
