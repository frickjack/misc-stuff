#
# Some AWS lambda helpers
#

source "${LITTLE_HOME}/lib/bash/utils.sh"

# lib ------------------------

#
# Determine mime type for a particular file name
#
# @param path
# @return echo mime type
#
s3webPath2ContentType() {
    local path="$1"
    shift
    case "$path" in
        *.html)
            echo "text/html; charset=utf-8"
            ;;
        *.json)
            echo "application/json; charset=utf-8"
            ;;
        *.js)
            echo "application/javascript; charset=utf-8"
            ;;
        *.mjs)
            echo "application/javascript; charset=utf-8"
            ;;
        *.css)
            echo "text/css; charset=utf-8"
            ;;
        *.svg)
            echo "image/svg+xml; charset=utf-8"
            ;;
        *.png)
            echo "image/png"
            ;;
        *.jpg)
            echo "image/jpeg"
            ;;
        *.webp)
            echo "image/webp"
            ;;
        *.txt)
            echo "text/plain; charset=utf-8"
            ;;
        *.md)
            echo "text/markdown; charset=utf-8"
            ;;
        *)
            echo "text/plain; charset=utf-8"
            ;;
    esac
}

#
# Get the npm package name from the `package.json`
# in the current directory
#
s3webPublish() {
    local srcFolder
    local destPrefix
    local dryRun=off

    if [[ $# -lt 2 ]]; then
        gen3_log_err "s3web publish takes 2 arguments"
        little help s3web
        return 1
    fi
    srcFolder="$1"
    shift
    destPrefix="$1"
    shift
    if [[ $# -gt 0 && "$1" =~ ^-*dryrun ]]; then
        shift
        dryRun=on
    fi
    if [[ ! -d "$srcFolder" ]]; then
        gen3_log_err "invalid source folder: $srcFolder"
        return 1
    fi
    if ! [[ "$destPrefix" =~ ^s3://.+ ]]; then
        gen3_log_err "destination prefix should start with s3:// : $destPrefix"
        return 1
    fi
    local filePath
    local ctype
    local encoding
    local cacheControl
    local errCount=0
    local gzTemp
    local commandList
    (
        commandList=()
        cd "$srcFolder"
        gzTemp="$(mktemp "$XDG_RUNTIME_DIR/gzTemp_XXXXXX")"
        find . -type f -print | while read -r filePath; do
            ctype="$(s3webPath2ContentType "$filePath")"
            encoding="gzip"
            cacheControl="max-age=3600000, public"
            destPath="${destPrefix%/}/${filePath#./}"
            if [[ "$ctype" =~ ^image/ && ! "$ctype" =~ ^image/svg ]]; then
                encoding=""
            fi
            if [[ "$ctype" =~ ^text/html || "$ctype" =~ ^application/json ]]; then
                cacheControl="max-age=3600, public"
            fi

            if [[ "$encoding" == "gzip" ]]; then
                gzip -c "$filePath" > "$gzTemp"
                commandList=(aws s3 cp "$gzTemp" "$destPath" --content-type "$ctype" --content-encoding "$encoding" --cache-control "$cacheControl")
            else
                commandList=(aws s3 cp "$filePath" "$destPath" --content-type "$ctype" --cache-control "$cacheControl")
            fi
            gen3_log_info "dryrun=$dryRun - ${commandList[@]}"
            if [[ "$dryRun" == "off" ]]; then
                "${commandList[@]}" 1>&2
            fi
            errCount=$((errCount + $?))
            if [[ -f "$gzTemp" ]]; then
                /bin/rm "$gzTemp"
            fi
        done
        [[ $errCount == 0 ]]
    )
}

# main ---------------------

# GEN3_SOURCE_ONLY indicates this file is being "source"'d
if [[ -z "${GEN3_SOURCE_ONLY}" ]]; then
    command="$1"
    shift

    case "$command" in
        "content-type")
            s3webPath2ContentType "$@"
            ;;
        "publish")
            s3webPublish "$@"
            ;;
        *)
            little help s3web
            ;;
    esac
fi
