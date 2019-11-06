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

source "$LITTLE_HOME/test/utilsTest.sh"
source "$LITTLE_HOME/test/littleTest.sh"
source "$LITTLE_HOME/test/lambdaTest.sh"
source "$LITTLE_HOME/test/s3webTest.sh"
source "$LITTLE_HOME/test/secretTest.sh"
source "$LITTLE_HOME/test/stackTest.sh"
shunit_summary
