
#
# Setup and delete secret
#
testS3webContentType() {
  local expected
  local ext
  local ctype
  local it
  local testList=(
    html "text/html; charset=utf-8"
    css "text/css; charset=utf-8"
    js "application/javascript; charset=utf-8"
    json "application/json; charset=utf-8"
    svg "image/svg+xml; charset=utf-8"
    png "image/png"
    jpg "image/jpeg"
    webp "image/webp"
    md "text/markdown; charset=utf-8"
    txt "text/plain; charset=utf-8"
    mjs "application/javascript; charset=utf-8"
  )
  local testCount=${#testList[@]}
  for ((it=0; it < testCount-1; it=it+2)); do
    ext="${testList[$it]}"
    expected="${testList[$((it+1))]}"
    ctype="$(little s3web content-type whatever/bla.$ext)" && [[ "$ctype" == "$expected" ]];
      because $? "$ext gets right content type: $ctype"
  done
}

testS3webPublish() {
  local testBucket
  local testFolder="${LITTLE_HOME}/lib/testData/testWeb"
  testBucket="$(little stack bucket)"; because $? "tests can re-use the stack bucket"
  little s3web publish "$testFolder" "s3://$testBucket/testData/testWeb";
    because $? "s3web publish worked - s3://$testBucket/testData/testWeb"
}

shunit_runtest "testS3webContentType" "s3web,local"
shunit_runtest "testS3webPublish" "s3web"
