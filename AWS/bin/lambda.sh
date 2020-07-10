#
# Some AWS lambda helpers
#

source "${LITTLE_HOME}/lib/bash/utils.sh"

# lib ------------------------


help() {
    bash "$LITTLE_HOME/bin/basic/help.sh" lambda
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
    name="${name//[ \/@.]/_}"
    name="${name#_}"
    echo "$name"
}

#
# Derive a sanitized lambda function name from the
# given nodejs (or whatever) package name.  
# Removes illegal
# characters, etc., starts with a letter
#
# @param packageName or defaults to lambadaPackName if not given
# @return echo the sanitized function name
#
lambdaFunctionName() {
    local name
    local packName=""

    if [[ $# -gt 0 ]]; then
      packName="$1"
      shift
    fi
    if ! packName="${packName:-$(lambdaPackageName)}"; then
      gen3_log_err "failed to determine package name from arguments or current folder $(pwd): $@"
      return 1
    fi
    name="${packName}"
    # do some cleanup - remove illegal characters, start with a letter
    echo "${name//[ \/@.]/_}"
}


lambdaDockerRun() {
    docker run --rm -v "$PWD":/var/task lambci/lambda:nodejs12.x "$@"
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
    find -L . -not -path '????*/node_modules*' -not -path '*/.*' -not -path '*.zip' | zip -@ bundle.zip > /dev/null || return 1
    echo "$(pwd)/bundle.zip"
    # send some summary info to stderr for logging
    (zipinfo -1 bundle.zip | grep -v node_modules | grep -v .git | head -100) 1>&2
    return 0
}

#
# Get the s3 folder prefix that the given code path would upload under.
#
# @param zipPath path to a local directory path to bundle up and copy to s3 - default to current folder
#
lambdaS3Folder() {
    local branch
    local packName
    local s3Folder
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
            bucket="$(little stack bucket)" && \
            packName="$(lambdaPackageName)" && \
            s3Folder="s3://${bucket}/lambda/${packName}/${layerName}" && \
            echo "$s3Folder"
    )
    return $?
}

#
# Publish the bundle.zip in the current
# folder to S3 folder
#
# @param zipPath path to a local directory path to bundle up and copy to s3 - default to current folder
# 
lambdaUpload() {
    local bundle
    local s3Folder
    local s3Path
    local zipPath="."

    if [[ $# -gt 0 ]]; then
      zipPath="$1"
      shift
    fi
    s3Folder="$(lambdaS3Folder "$zipPath")" || return $?

    (
        cd "$zipPath" && \
            bundle="$(lambdaBundle)" && \
            # this aggressive cleanup screws up cloudformation rollback
            #   (aws s3 rm --recursive "${s3Folder}" || true) 1>&2 && \
                        # this aggressive cleanup screws up cloudformation rollback
            #   (aws s3 rm --recursive "${s3Folder}" || true) 1>&2 && \
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
# publish to lambda layer under dev/${package-name}_${package_version}_${branch}
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
    
    if ! bucket="$(little stack bucket)"; then
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
            "nodejs12.x"
        ],
        "LicenseInfo": "ISC"
    }
EOM
    )
    jq -r . 1>&2 <<< "$commandJson"
    aws lambda publish-layer-version --cli-input-json "$commandJson"
}

#
# List the log-streams associated with the given lambda function
#
# @param functionName
# @param functionVersion defaults to '$LATEST'
#
lambdaLogStreams() {
    local functionName
    functionName="$1"
    shift || return 1
    local functionVersion="${1:-\$LATEST}"
    local logGroup="/aws/lambda/$functionName"
    (aws logs describe-log-streams --log-group-name "$logGroup" --order-by LastEventTime --descending  --page-size 50 --max-items 100 || echo ERROR) | jq --arg versionSelector "[$functionVersion]" -r '.logStreams | map(select(.logStreamName | contains($versionSelector)))'
}

#
# List the events from the most recent log stream
# associated with the given lambda function
#
# @param functionName
# @param functionVersion defaults to '$LATEST'
#
lambdaLogEvents() {
    local streamInfo
    local streamName
    streamInfo="$(lambdaLogStreams "$@")" || return 1
    streamName="$(jq -e -r '.[0].logStreamName' <<< "$streamInfo")" && [[ -n "$streamName" ]] || return 1
    local functionName="$1"
    local logGroup="/aws/lambda/$functionName"
    aws logs get-log-events --log-group-name "$logGroup" --log-stream-name "${streamName}" | jq -r '.events | map(.timeStampDate = (.timestamp | todate))'
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
        "layer-name")
            lambdaLayerName "$@"
            ;;
        "package-name")
            lambdaPackageName "$@"
            ;;
        "git-branch")
            lambdaGitBranch "$@"
            ;;
        "log-streams")
            lambdaLogStreams "$@"
            ;;
        "log-events")
            lambdaLogEvents "$@"
            ;;
        "s3-folder")
            lambdaS3Folder "$@"
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
