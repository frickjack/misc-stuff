#
# Some AWS lambda helpers
#

source "${LITTLE_HOME}/lib/bash/utils.sh"

# lib ------------------------


help() {
    bash "$LITTLE_HOME/bin/help.sh" lambda
}

#
# Get the npm package name from the `package.json`
# in the current directory
#
lambdaPackageName() {
    if [[ ! -f package.json ]]; then
        gen3_log_err "no file ./package.json in current folder"
        return 1
    fi
    jq -e -r .name < ./package.json
}

#
# Get the npm package version from the `package.json`
# in the current directory
#
lambdaPackageVersion() {
    if [[ ! -f package.json ]]; then
        gen3_log_err "no file ./package.json in current folder"
        return 1
    fi
    jq -e -r .version < ./package.json
}

#
# Get the git branch of the current directory
#
lambdaGitBranch() {
    git rev-parse --abbrev-ref HEAD
}

#
# Derive a sanitized lambda layer name from the
# given nodejs (or whatever) package name and
# git (or whatever) git branch.  Removes illegal
# characters, etc., starts with a letter
#
# @param packageName or defaults to lambadaPackName if not given
# @param packageVersion or defaults to lambdaPackVersion if not given
# @param branchName or defaults to lambadaGitBranch if not given
# @return echo the sanitized layer name
#
lambdaLayerName() {
    local name
    local packName=""
    local packVersion=""
    local gitBranch=""

    if [[ $# -gt 0 ]]; then
      packName="$1"
      shift
    fi
    if [[ $# -gt 0 ]]; then
      packVersion="$1"
      shift
    fi
    if [[ $# -gt 0 ]]; then
      gitBranch="$1"
      shift
    fi
    if ! packName="${packName:-$(lambdaPackageName)}" \
        || ! packVersion="${packVersion:-$(lambdaPackageVersion)}" \
        || ! gitBranch="${gitBranch:-$(lambdaGitBranch)}"; then
      gen3_log_err "failed to determine package name, version, and git branch from arguments or current folder $(pwd): $@"
      return 1
    fi
    name="${packName}-${packVersion}-${gitBranch}"
    # do some cleanup - remove illegal characters, start with a letter
    echo "${name//[ \/@.]/_}"
}


lambdaDockerRun() {
    docker run --rm -v "$PWD":/var/task lambci/lambda:nodejs10.x "$@"
}

#
# Zip up the current folder assuming
# it's a nodejs folder
#
lambdaBundle() {
    if ! (lambdaGitBranch > /dev/null && [[ -f ./package.json ]]); then
        gen3_log_err "lambda package bailing out - missing .git or package.json"
        return 1
    fi
    if [[ -f ./bundle.zip ]]; then
      /bin/rm ./bundle.zip
    fi
    zip -r bundle.zip . > /dev/null 2>&1 && echo "$(pwd)/bundle.zip"
    local result=$?
    (zipinfo bundle.zip | grep -v node_modules | grep -v .git | head -100) 1>&2
    return $result
}


#
# Publish the bundle.zip in the current
# folder to S3 folder
#
# @param zipPath path to a local directory path to bundle up and copy to s3 - default to current folder
# 
lambdaUpload() {
    local bundle
    local branch
    local cleanBranch
    local packName
    local s3Folder
    local s3Path
    local bucket
    local zipPath="."

    if [[ $# -gt 0 ]]; then
      zipPath="$1"
      shift
    fi
    if [[ ! -d "$zipPath" ]]; then
        gen3_log_err "no such folder: $zipPath"
        return 1
    fi
    (
        cd "$zipPath" && \
            layerName="$(lambdaLayerName)" && \
            bucket="$(arun stack bucket)" && \
            packName="$(lambdaPackageName)" && \
            bundle="$(lambdaBundle)" && \
            s3Folder="s3://${bucket}/lambda/${packName}/${layerName}" && \
            #
            # do not clean up old packages at this time -
            # it can screw up cloudformation rollback if
            # a stack references a key
            #
            # (aws s3 rm --recursive "${s3Folder}" || true) 1>&2 && \
            s3Path="${s3Folder}/bundle-$(date -u +%Y%m%d_%H%M%S).zip" && \
            gen3_log_info "Uploading $bundle to $s3Path" && \
            aws s3 cp "${bundle}" "$s3Path" 1>&2 && \
            echo $s3Path
    )
    return $?
}

#
# Publish the bundle.zip in the current
# folder.  Copy to S3 folder, then
# publish to lambda layer under dev/${package_name}_${package_version}_${branch}
#
# @param zipPath the s3://... path of the local folder path to bundle up and copy to s3 -
#           defaults to current folder
# 
lambdaUpdateLayer() {
    local bundle
    local layerName
    local commandJson
    local bucket
    local zipPath="."

    if [[ $# -gt 0 ]]; then
      zipPath="$1"
      shift
    fi
    
    if ! bucket="$(arun stack bucket)"; then
        gen3_log_err "failed to determine lambda bucket"
        return 1
    fi
    if ! layerName="$(cd "$zipPath" && lambdaLayerName)"; then
      gen3_log_err "failed to derive layer name, bailing out of layer update"
      return 1
    fi
    if ! bundle="$(lambdaUpload "$zipPath" "$@")"; then
        gen3_log_err "failed to upload code bundle, bailing out of layer update"
        return 1
    fi

    # delete old versions before creating a new one
    local arn
    for arn in $(aws lambda list-layer-versions --layer-name "$layerName" | jq -r '.LayerVersions | map(.LayerVersionArn) | del(.[0]) | .[]'); do
        gen3_log_info "deleting old layer version $arn"
        aws lambda delete-layer-version --layer-name "$layerName" --version-number "${arn##*:}" 1>&2
    done

    commandJson=$(cat - <<EOM
    {
        "LayerName": "$layerName",
        "Description": "",
        "Content": {
            "S3Bucket": "$bucket",
            "S3Key": "${bundle#s3://*/}"
        },
        "CompatibleRuntimes": [
            "nodejs10.x"
        ],
        "LicenseInfo": "ISC"
    }
EOM
    )
    jq -r . 1>&2 <<< "$commandJson"
    aws lambda publish-layer-version --cli-input-json "$commandJson"
}


# main ---------------------

# GEN3_SOURCE_ONLY indicates this file is being "source"'d
if [[ -z "${GEN3_SOURCE_ONLY}" ]]; then
    command="$1"
    shift

    case "$command" in
        "bundle")
            lambdaBundle "$@"
            ;;
        "drun")
            lambdaDockerRun "$@"
            ;;
        "layer_name")
            lambdaLayerName "$@"
            ;;
        "package_name")
            lambdaPackageName "$@"
            ;;
        "git_branch")
            lambdaGitBranch "$@"
            ;;
        "update")
            lambdaUpdateLayer "$@"
            ;;
        "upload")
            lambdaUpload "$@"
            ;;
        *)
            help
            ;;
    esac
fi
