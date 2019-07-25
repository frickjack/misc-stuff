
test_package_name() {
    local name
    local testDir
    testDir="$XDG_RUNTIME_DIR/$$_$RANDOME"
    mkdir -p "$testDir" && cd "$testDir"; because $? "successfully setup test folder: $testDir"
    /bin/rm -rf package.json
    ! name="$(arun lambda package_name 2> /dev/null)"; because $? "cannot derive package name if package.json does not exist"
    (cat - <<EOM
{
"name": "bogus"
}        
EOM
    ) > package.json
    name="$(arun lambda package_name)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == 'bogus' ]];
        because $? "derived expected npm package name from package.json: $name"
}

test_git_branch() {
    local name
    local testDir
    testDir="$XDG_RUNTIME_DIR/$$_$RANDOME"
    mkdir -p "$testDir" && cd "$testDir"; because $? "successfully setup test folder: $testDir"
    /bin/rm -rf .git
    ! name="$(arun lambda git_branch 2> /dev/null)"; because $? "cannot derive git branch if .git does not exist"
    git init
    touch bla
    git add bla
    git commit -m 'frick'
    git checkout -b frickjack
    name="$(arun lambda git_branch)" \
        && /bin/rm -rf "$testDir" \
        && [[ "$name" == 'frickjack' ]];
        because $? "derived expected git branch: $name"
}

shunit_runtest "test_package_name" "lambda"
shunit_runtest "test_git_branch" "lambda"
