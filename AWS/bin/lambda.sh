#
# Some AWS lambda helpers
#

source "${LITTLE_HOME}/lib/bash/utils.sh"


# lib ------------------------

help() {
    bash "$LITTLE_HOME/bin/help.sh" stack
}

#
# Get the npm package name from the `package.json`
# in the current directory
#
lambda_package_name() {
    if [[ ! -f package.json ]]; then
        gen3_log_err "no file ./package.json in current folder"
        return 1
    fi
    jq -e -r .name < ./package.json
}

#
# Get the git branch of the current directory
#
lambda_git_branch() {
    if [[ ! -d .git ]]; then
        gen3_log_err "no .git/ folder in current folder"
        return 1
    fi
    git rev-parse --abbrev-ref HEAD
}


lambda_drun() {
    docker run --rm -v "$PWD":/var/task lambci/lambda:nodejs10.x "$@"
}


# main ---------------------

# GEN3_SOURCE_ONLY indicates this file is being "source"'d
if [[ -z "${GEN3_SOURCE_ONLY}" ]]; then
    command="$1"
    shift

    case "$command" in
        "drun")
            lambda_drun "$@"
            ;;
        "package_name")
            lambda_package_name "$@"
            ;;
        "git_branch")
            lambda_git_branch "$@"
            ;;
        *)
            help
            ;;
    esac
fi
