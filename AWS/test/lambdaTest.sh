
#
# Setup folder with package.json and git,
# checkout a branch, and cd to the folder
#
testLamdaSetup() {
    local testDir
    testDir="$XDG_RUNTIME_DIR/$$_$RANDOM"
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
"name": "@littleware/bogus",
"version": 1.0.0
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

testLambdaPackageName() {
    local name
    local testDir
    testDir="$(testLamdaSetup)" && cd "$testDir"; 
        because $? "test setup should succeed: $testDir"
    name="$(arun lambda package_name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == '@littleware/bogus' ]];
        because $? "derived expected npm package name from package.json: $name"
}

testLambdaGitBranch() {
    local name
    local testDir
    testDir="$(testLamdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    name="$(arun lambda git_branch)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == 'frickjack' ]];
        because $? "derived expected git branch: $name"
}

testLambdaLayerName() {
    local name
    local testDir
    testDir="$(testLamdaSetup)" && cd "$testDir"; 
        because $? "test setup should succeed: $testDir"
    name="$(cd /tmp && arun lambda layer_name "$testDir")" \
        && [[ "$name" == '_littleware_bogus-1.0.0-frickjack' ]];
        because $? "derived expected layer name given folder: $name"
    name="$(arun lambda layer_name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == '_littleware_bogus-1.0.0-frickjack' ]];
        because $? "derived expected lambda layer name from package.json and git branch: $name"
}

testLambdaBundle() {
    local path
    local testDir
    testDir="$(testLamdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    path="$(arun lambda bundle)" \
        && [[ "$path" =~ /bundle.zip$ && -f "$path" ]] \
        && /bin/rm -rf "$testDir";
        because $? "arun lambda bundle creates a bundle.zip: $path"
}

testLambdaUpload() {
    local path
    local testDir
    testDir="$(testLamdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    path="$(arun lambda upload)" \
        && /bin/rm -rf "$testDir";
        because $? "arun lambda upload should succeed"
    [[ "$path" =~ ^s3://.+/_littleware_bogus/_littleware_bogus-1.0.0-frickjack/bundle-[0-9]+_[0-9]+.zip$ ]];
        because $? "arun lambda upload uploads a bundle.zip: $path"
    aws s3 ls "$path" > /dev/null 2>&1; because $? "arun lambda upload creats an s3 object at $path"
}

testLambdaUpdate() {
    local data
    local testDir
    testDir="$(testLamdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    data="$(arun lambda update)" \
        && /bin/rm -rf "$testDir";
        because $? "arun lambda update should succeed"
    jq -r .LayerVersionArn <<<"$data"; because $? "arun lambda update should return layer version data"
}

shunit_runtest "testLambdaGitBranch" "lambda"
shunit_runtest "testLambdaLayerName" "lambda"
shunit_runtest "testLambdaPackageName" "lambda"
shunit_runtest "testLambdaBundle" "lambda"
shunit_runtest "testLambdaUpload" "lambda"
shunit_runtest "testLambdaUpdate" "lambda"
