#
# Some AWS lambda helpers
#

source "${LITTLE_HOME}/lib/bash/utils.sh"

# globals --------------------

profile="${AWS_PROFILE:-default}"

if ! region="$(aws --profile "$profile" configure get region)"; then
    echo "ERROR: aws configure get region failed" 1>&2
    return 1
fi

bucket="cloudformation-frickjack-$region"


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

#
# Zip up the current folder assuming
# its a nodejs folder
#
lambda_bundle() {
    if ! [[ -d .git && -f ./package.json ]]; then
        gen3_log_err "lambda package bailing out - missing .git or package.json"
        return 1
    fi
    if [[ -f ./bundle.zip ]]; then
      /bin/rm ./bundle.zip
    fi
    zip -r bundle.zip * 1>&2 && echo "$(pwd)/bundle.zip"
}

#
# Publish the bundle.zip in the current
# folder.  Copy to S3 folder, then
# publish to lambda under dev/${package_name}_${branch}
#
# @param lambdaName the lambda to update with the new code
# @param zipPath the s3://... path of the bundle.zip, 
#           or a local file path to bundle up and copy to s3
# 
lambda_update() {
    local bundle
    local branch
    local packName
    local funcName
    branch="$(lambda_git_branch)" && \
      packame="$(lambda_package_name)" && \
      bundle="$(lambda_bundle)"
    funcName="${packName}-${branch}"
    aws lambda create-function --function-name "$funcName" --runtime nodejs10.x
}

#
# Publish the bundle.zip in the current
# folder to S3 folder
#
# @param zipPath path to a local directory path to bundle up and copy to s3
# 
lambda_upload() {
    local bundle
    local branch
    local packName
 
    branch="$(lambda_git_branch)" && \
      packame="$(lambda_package_name)" && \
      bundle="$(lambda_bundle)"
    funcName="${packName}-${branch}"
    aws lambda create-function --function-name "$funcName" --runtime nodejs10.x
}

# main ---------------------

# GEN3_SOURCE_ONLY indicates this file is being "source"'d
if [[ -z "${GEN3_SOURCE_ONLY}" ]]; then
    command="$1"
    shift

    case "$command" in
        "bundle")
            lambda_bundle "$@"
            ;;
        "drun")
            lambda_drun "$@"
            ;;
        "package_name")
            lambda_package_name "$@"
            ;;
        "git_branch")
            lambda_git_branch "$@"
            ;;
        "update")
            lambda_update "$@"
            ;;
        "upload")
            lambda_upload "$@"
            ;;
        *)
            help
            ;;
    esac
fi
