
#
# Setup folder with package.json and git,
# checkout a branch, and cd to the folder
#
test_setup_bogus() {
    local testDir
    testDir="$XDG_RUNTIME_DIR/$$_$RANDOME"
    mkdir -p "$testDir" && cd "$testDir";
      because $? "successfully setup test folder: $testDir" 1>&2
    /bin/rm -rf package.json
    /bin/rm -rf .git
    ! name="$(arun lambda git_branch 2> /dev/null)";
        because $? "cannot derive git branch if .git does not exist" 1>&2
    ! name="$(arun lambda package_name 2> /dev/null)";
        because $? "cannot derive package name if package.json does not exist" 1>&2
    (cat - <<EOM
{
"name": "@littleware/bogus"
}        
EOM
    ) > package.json
    (
        git init
        touch bla
        git add bla
        git add package.json
        git commit -m 'frick'
        git checkout -b frickjack
    ) 1>&2
    echo "$testDir"
}

test_package_name() {
    local name
    local testDir
    testDir="$(test_setup_bogus)" && cd "$testDir"; 
        because $? "test setup should succeed: $testDir"
    name="$(arun lambda package_name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == '@littleware/bogus' ]];
        because $? "derived expected npm package name from package.json: $name"
}

test_git_branch() {
    local name
    local testDir
    testDir="$(test_setup_bogus)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    name="$(arun lambda git_branch)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == 'frickjack' ]];
        because $? "derived expected git branch: $name"
}

test_layer_name() {
    local name
    local testDir
    testDir="$(test_setup_bogus)" && cd "$testDir"; 
        because $? "test setup should succeed: $testDir"
    name="$(arun lambda layer_name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == '_littleware_bogus-frickjack' ]];
        because $? "derived expected lambda layer name from package.json and git branch: $name"
}

test_lambda_bundle() {
    local path
    local testDir
    testDir="$(test_setup_bogus)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    path="$(arun lambda bundle)" \
        && [[ "$path" =~ /bundle.zip$ && -f "$path" ]] \
        && /bin/rm -rf "$testDir";
        because $? "arun lambda bundle creates a bundle.zip: $path"
}

test_lambda_upload() {
    local path
    local testDir
    testDir="$(test_setup_bogus)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    path="$(arun lambda upload)" \
        && /bin/rm -rf "$testDir";
        because $? "arun lambda upload should succeed"
    [[ "$path" =~ ^s3://.+/_littleware_bogus-frickjack.zip$ ]];
        because $? "arun lambda upload uploads a bundle.zip: $path"
    aws s3 ls "$path" > /dev/null 2>&1; because $? "arun lambda upload creats an s3 object at $path"
}

test_lambda_update() {
    local data
    local testDir
    testDir="$(test_setup_bogus)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    data="$(arun lambda update)" \
        && /bin/rm -rf "$testDir";
        because $? "arun lambda update should succeed"
    jq -r .LayerVersionArn <<<"$data"; because $? "arun lambda update should return layer version data"
}

shunit_runtest "test_git_branch" "lambda"
shunit_runtest "test_layer_name" "lambda"
shunit_runtest "test_package_name" "lambda"
shunit_runtest "test_lambda_bundle" "lambda"
shunit_runtest "test_lambda_upload" "lambda"
shunit_runtest "test_lambda_update" "lambda"
