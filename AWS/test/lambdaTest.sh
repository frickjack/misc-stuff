
#
# Setup folder with package.json and git,
# checkout a branch, and cd to the folder
#
testLambdaSetup() {
    local testDir
    testDir="$XDG_RUNTIME_DIR/$$_$RANDOM"
    mkdir -p "$testDir" && cd "$testDir";
      because $? "successfully setup test folder: $testDir" 1>&2
    /bin/rm -rf package.json
    /bin/rm -rf .git
    ! name="$(little lambda git-branch 2> /dev/null)";
        because $? "cannot derive git branch if .git does not exist" 1>&2
    ! name="$(little lambda package-name 2> /dev/null)";
        because $? "cannot derive package name if package.json does not exist" 1>&2
    (cat - <<EOM
{
"name": "@littleware/bogus",
"version": "1.0.0"
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
    testDir="$(testLambdaSetup)" && cd "$testDir"; 
        because $? "test setup should succeed: $testDir"
    name="$(little lambda package-name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == '@littleware/bogus' ]];
        because $? "derived expected npm package name from package.json: $name"
}

testLambdaGitBranch() {
    local name
    local testDir
    testDir="$(testLambdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    name="$(little lambda git-branch)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == 'frickjack' ]];
        because $? "derived expected git branch: $name"
}

testLambdaLayerName() {
    local name
    local testDir
    testDir="$(testLambdaSetup)" && cd "$testDir"; 
        because $? "test setup should succeed: $testDir"
    name="$(little lambda layer-name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == 'littleware_bogus-1_0_0-frickjack' ]];
        because $? "derived expected lambda layer name from package.json and git branch: $name"
}

testLambdaBundle() {
    local path
    local testDir
    testDir="$(testLambdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    path="$(little lambda bundle)" \
        && [[ "$path" =~ /bundle.zip$ && -f "$path" ]] \
        && /bin/rm -rf "$testDir";
        because $? "little lambda bundle creates a bundle.zip: $path"
}

testLambdaUpload() {
    local path
    local testDir
    testDir="$(testLambdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    path="$(little lambda upload)" \
        && cd "$XDG_RUNTIME_DIR" \
        && /bin/rm -rf "$testDir";
        because $? "little lambda upload should succeed: $path"
    [[ "$path" =~ ^s3://.+/@littleware/bogus/_littleware_bogus-1_0_0-frickjack/bundle-[0-9]+_[0-9]+.zip$ ]];
        because $? "little lambda upload uploads a bundle.zip: $path"
    local clean="${path##s3://}"
    aws s3api head-object --bucket "${clean%%/*}" --key "${clean#*/}" 1>&2; because $? "little lambda upload creates an s3 object at $path"
}

testLambdaUpdate() {
    local data
    local testDir
    testDir="$(testLambdaSetup)" && cd "$testDir";
        because $? "test setup should succeed: $testDir"
    data="$(little lambda update)" \
        && /bin/rm -rf "$testDir";
        because $? "little lambda update should succeed"
    jq -r .LayerVersionArn <<<"$data"; because $? "little lambda update should return layer version data"
}

shunit_runtest "testLambdaGitBranch" "lambda"
shunit_runtest "testLambdaLayerName" "lambda"
shunit_runtest "testLambdaPackageName" "lambda"
shunit_runtest "testLambdaBundle" "lambda"
shunit_runtest "testLambdaUpload" "lambda"
shunit_runtest "testLambdaUpdate" "lambda"
