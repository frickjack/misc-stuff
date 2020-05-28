testStackValidate() {
  local templates
  local path
  local folder
  local variables
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml' | grep -v openapi | grep -v petstore | grep -v sampleStackParams)"
  for path in $templates; do
    folder="$(dirname "$path")"
    variables="$(little stack variables)"; because $? "stack filter collected default variable set"
    if [[ -f "$folder/sampleStackParams.json" ]]; then
      variables="$(little stack variables "$folder/sampleStackParams.json")"
    fi
    gen3_log_info "Validating template at $path with variables $variables"
    little stack validate-template "$path" "$variables"; because $? "this is a valid template: $path"
  done
}

testStackFilter() {
  local templates
  local path
  local folder
  local variables
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml'  | grep -v openapi | grep -v petstore | grep -v sampleStackParams)"
  for path in $templates; do
    folder="$(dirname "$path")"
    variables="$(little stack variables)"; because $? "stack filter collected default variable set"
    if [[ -f "$folder/sampleStackParams.json" ]]; then
      variables="$(little stack variables "$folder/sampleStackParams.json")"
    fi
    gen3_log_info "Testing filter-template on $path with variables $variables"
    (little stack filter-template "$path" "$variables" || echo "ERROR") | jq -e -r . > /dev/null; because $? "filter template works for: $path with $variables"
  done
}

testStackVariables() {
  local testPath="$LITTLE_HOME/lib/cloudformation/cellSetup/sampleStackParams.json"
  local varData
  varData="$(little stack variables)" && jq -r . <<< "$varData" > /dev/null;
    because $? "default stack variables look ok"
  varData="$(little stack variables "$testPath")" && jq -r . <<< "$varData" > /dev/null; 
    because $? "get stack variables worked as expected with $testPath: $varData"
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
shunit_runtest "testStackVariables" "stack"
