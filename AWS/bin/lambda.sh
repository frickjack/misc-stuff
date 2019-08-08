#
# Some AWS lambda helpers
#

source "${LITTLE_HOME}/lib/bash/utils.sh"

# globals --------------------

_lambdaBucket=""

# lib ------------------------


lambdaBucketName() {
    if [[ -n "$_lambdaBucket" ]]; then
      echo "$_lambdaBucket"
      return 0
    fi

    local profile="${AWS_PROFILE:-default}"
    local region
    local accountId
    if ! region="$(aws --profile "$profile" configure get region)"; then
        gen3_log_err "aws configure get region failed"
        return 1
    fi

    if ! accountId="$(aws iam list-account-aliases | jq -r '.AccountAliases[0]')"; then
        gen3_log_err "could not determine AWS account alias"
        return 1
    fi
    _lambdaBucket="cloudformation-${accountId}-$region"
    echo "$_lambdaBucket"
    return 0
}

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
# Get the git branch of the current directory
#
lambdaGitBranch() {
    if [[ ! -d .git ]]; then
        gen3_log_err "no .git/ folder in current folder"
        return 1
    fi
    git rev-parse --abbrev-ref HEAD
}

#
# Derive a sanitized lambda layer name from the
# given nodejs (or whatever) package name and
# git (or whatever) git branch.  Removes illegal
# characters, etc.
#
# @param packageName or defaults to lambada_pack_name if not given
# @param branchName or defaults to lambada_pack_name if not given
# @return echo the sanitized layer name
#
lambdaLayerName() {
    local name
    local packName=""
    local gitBranch=""

    if [[ $# -gt 0 ]]; then
      packName="$1"
      shift
    fi
    if [[ $# -gt 0 ]]; then
      gitBranch="$1"
      shift
    fi
    if ! packName="${packName:-$(lambdaPackageName)}" || ! gitBranch="${gitBranch:-$(lambdaGitBranch)}"; then
      gen3_log_err "failed to determine package name and git branch from arguments or current folder $(pwd): $@"
      return 1
    fi
    name="${packName}-${gitBranch}"
    echo "${name//[ \/@]/_}"
}


lambdaDockerRun() {
    docker run --rm -v "$PWD":/var/task lambci/lambda:nodejs10.x "$@"
}

#
# Zip up the current folder assuming
# its a nodejs folder
#
lambdaBundle() {
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
# folder to S3 folder
#
# @param zipPath path to a local directory path to bundle up and copy to s3
# 
lambdaUpload() {
    local bundle
    local branch
    local cleanBranch
    local packName
    local s3Path
    local bucket
 
    layerName="$(lambdaLayerName)" && \
      bucket="$(lambdaBucketName)" && \
      packName="$(lambdaPackageName)" && \
      bundle="$(lambdaBundle)" && \
      s3Path="s3://${bucket}/lambda/${packName}/${layerName}.zip" && \
      gen3_log_info "Uploading $s3Path" && \
      aws s3 cp "${bundle}" "$s3Path" 1>&2 && \
      echo $s3Path
}

#
# Publish the bundle.zip in the current
# folder.  Copy to S3 folder, then
# publish to lambda layer under dev/${package_name}_${branch}
#
# @param layerName the lambda layer to update with the new code
# @param zipPath the s3://... path of the bundle.zip, 
#           or a local file path to bundle up and copy to s3
# 
lambdaUpdateLayer() {
    local bundle
    local layerName
    local commandJson
    local bucket
    
    if ! bucket="$(lambdaBucketName)"; then
        gen3_log_err "failed to determine lambda bucket"
        return 1
    fi
    if ! layerName="$(lambdaLayerName)"; then
      gen3_log_err "failed to derive layer name, bailing out of layer update"
      return 1
    fi
    if ! bundle="$(lambdaUpload)"; then
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
    cat - 1>&2 <<<$commandJson
    aws lambda publish-layer-version --cli-input-json "$commandJson"
}


# main ---------------------

# GEN3_SOURCE_ONLY indicates this file is being "source"'d
if [[ -z "${GEN3_SOURCE_ONLY}" ]]; then
    command="$1"
    shift

    case "$command" in
        "bucket")
            lambdaBucketName "$@"
            ;;
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
