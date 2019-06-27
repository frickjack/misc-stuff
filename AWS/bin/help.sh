#!/bin/bash

README="$LITTLE_HOME/doc/README.md"
detail="$1"
PAGER="${PAGER:-less}"

open() {
  local filePath="$1"
  cat - "$filePath" <<< "$filePath" | $PAGER
}
if [[ -z "$detail" ]]; then
  open "$README"
  exit $?
fi

# Try to find an exact match
filePath="$(find "$LITTLE_HOME/doc" -name "${detail}.md" -print | head -1)"
if [[ -n "$filePath" ]]; then
  open "$filePath"
  exit $?
fi

# Try to help the user find what she wants
echo "Could not find ${detail}.md under $LITTLE_HOME/doc"
echo --------------
echo grep "$README"
grep "$detail" "$README"
