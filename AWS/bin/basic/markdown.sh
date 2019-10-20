#!/bin/bash
#
# Little helper calls through to `npx marked`
#

source "${LITTLE_HOME}/lib/bash/utils.sh"

# lib --------------------

render() {
    if [[ ! -e "$LITTLE_HOME/../node_modules/.bin/marked" ]]; then
        gen3_log_info "loading npm modules ..."        
        (cd "$LITTLE_HOME" && npm install) 1>2
    fi
    "$LITTLE_HOME/../node_modules/.bin/marked" "$@"
}

# -------------------

render "$@"