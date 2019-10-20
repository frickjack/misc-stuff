testStackValidate() {
  local templates
  local path
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml' | grep -v openapi | grep -v petstore)"
  for path in $templates; do
    gen3_log_info "Validating template at $path"
    little stack validate-template "$path"; because $? "this is a valid template: $path"
  done
}

testStackFilter() {
  local templates
  local path
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml'  | grep -v openapi | grep -v petstore)"
  for path in $templates; do
    gen3_log_info "Testing filter-template on $path"
    little stack filter-template "$path" | jq -e -r . > /dev/null; because $? "filter template works for: $path"
  done
}

testStackBucketName() {
  local bucket
  bucket=$(little stack bucket) && [[ "$bucket" =~ ^cloudformation-.+ ]];
    because $? "little stack bucket looks like cloudformation-account-region"
}

testStackCreate() {
  little stack create --dryRun "${LITTLE_HOME}/db/cloudformation/frickjack/accountSetup/snsNotify/stackParams.json";
    because $? "stack create --dryRun should run ok"
}

testStackChange() {
  little stack make-change --dryRun "${LITTLE_HOME}/db/cloudformation/frickjack/accountSetup/snsNotify/stackParams.json";
    because $? "stack make-change --dryRun should run ok"
}

testStackChangeName() {
  local actual
  local shouldbe="little-${USER}-${HOSTNAME}"
  shouldbe="${shouldbe//[_. ]/-}"
  actual="$(little stack change-name)" && [[ "$shouldbe" == "$actual" ]]; 
    because $? "stack change-name gave expected name: $shouldbe ?= $actual"
}

shunit_runtest "testStackBucketName" "stack"
shunit_runtest "testStackChange" "stack"
shunit_runtest "testStackChangeName" "stack"
shunit_runtest "testStackCreate" "stack"
shunit_runtest "testStackFilter" "stack"
shunit_runtest "testStackValidate" "stack"
