#!/bin/bash
#
# Little wrapper around aws sns publish
#

# lib --------------------

#
# Publish a message to an SNS topic
#
# @param topicName to grep for in aws sns list-topics
# @param message
# @return 0 on success
#
publish() {
    local topicName
    local message
    
    if [[ $# -lt 2 ]]; then
      echo "ERROR: public takes 2+ arguments: topicName message ..." 1>&2
      return 1
    fi
    topicName="$1"
    shift
    message="$1"
    shift
    local topicsList
    local topicArn
    if topicsList="$(aws sns list-topics | jq -r '.Topics[] | .TopicArn')" \
        && topicArn=($(echo "$topicsList" | grep -i "$topicName")); 
    then
        if [[ "${#topicArn[@]}" -ne 1 ]]; then
          echo "ERROR: multiple matching topics: ${topicArn[@]}" 1>&2
          return 1
        fi
        echo "INFO: publishing to ${topicArn[0]}" 1>&2
        aws sns publish --topic-arn "${topicArn[0]}" --message "$message"
        return $?
    else
        echo "ERROR: no topic matches $topicName : $topicsList" 1>&2
        return 1
    fi
}

# main ---------------

publish "$@"