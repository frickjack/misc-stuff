test_stack_validate() {
  local templates
  local path
  templates="$(find "$LITTLE_HOME/lib/cloudformation/" -type f -name '*.json' -o -name '*.yaml')"
  for path in $templates; do
    arun stack validate "$path"; because $? "this is a valid template: $path"
  done
}

shunit_runtest "test_stack_validate" "stack"
