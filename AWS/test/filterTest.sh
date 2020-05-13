
testFilterTemplate() {
    gen3_log_info "Generating test template and variables"
    local testTemplate="$(
        cat - <<EOM
{
    "{{templateKey1}}": {
        "whatever": "{{templateKey2}}"
    },
    "items": [
        {% for item in items %}
            "{{item}}" {% if not loop.last %},{% endif %}
        {% endfor %}
    ]
}
EOM
    )"
    local variables='{ "templateKey1": "keyA", "templateKey2": "whateverValue", "items": [ "Aa", "Bb", "Cc" ] }'
    local it
    local filterResult
        
    filterResult="$(little filter "$variables" <<< "$testTemplate")" \
        && it="$(jq -e -r .keyA.whatever <<< "$filterResult")" \
        && [[ "$it" == "whateverValue" ]] \
        && it="$(jq -e -r '.items[1]' <<< "$filterResult")" \
        && [[ "$it" == "Bb" ]];
        because $? "little filter gave expected result: $filterResult"
}

shunit_runtest "testFilterTemplate" "local,filter"
