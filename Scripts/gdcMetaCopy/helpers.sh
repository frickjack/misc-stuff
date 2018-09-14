#
# Source this file to pull some helper functions into your shell
#

export INDEX_HOSTNAME="${INDEX_HOSTNAME:-nci-crdc.datacommons.io}"

function ifetch() {
  local id
  id="$1"
  curl "https://${INDEX_HOSTNAME}/index/$id" | jq -r
}
