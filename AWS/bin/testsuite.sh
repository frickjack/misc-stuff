source "${LITTLE_HOME}/lib/bash/utils.sh"
gen3_load "lib/bash/shunit"

#
# NOTE: The tests in this file require a particular test environment
# that can run terraform and interact with kubernetes.
# The tests in g3k_testsuite.sh should run anywhere.
#

help() {
  little help testsuite
  return 0
}

if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi
while [[ $# > 0 ]]; do
  command="$1"
  shift
  if [[ "$command" =~ ^-*filter$ ]]; then
    shunit_set_filters "$1"
    shift
  else
    help
    exit 1
  fi
done

for name in "$LITTLE_HOME/test/"*Test.sh; do
  source "$name"
done

shunit_summary
