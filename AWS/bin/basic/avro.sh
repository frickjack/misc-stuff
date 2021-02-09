#!/bin/bash

jarfile="$LITTLE_HOME/lib/avro-tools-1.10.1.jar"

if [[ ! -f "$jarfile" ]]; then
  curl -o "$jarfile" https://repo1.maven.org/maven2/org/apache/avro/avro-tools/1.10.1/avro-tools-1.10.1.jar 1>&2
fi

java -jar "$LITTLE_HOME/lib/avro-tools-1.10.1.jar" "$@"

