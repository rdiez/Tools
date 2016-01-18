#!/bin/bash

# This example scripts calls update-backup-mirror-by-modification-time.sh twice
# with a single background.sh invocation in order to display just one
# notification at the end.

set -o errexit
set -o nounset
set -o pipefail


SRC1="$HOME/src/src1"
SRC2="$HOME/src/src2"
DEST1="$HOME/dest/dest1"
DEST2="$HOME/dest/dest2"

# The backup process.
if true; then
  CMDS="./update-backup-mirror-by-modification-time.sh \"/$SRC1\" \"$DEST1\""
  CMDS+=" && ./update-backup-mirror-by-modification-time.sh \"$SRC2\" \"$DEST2\""

  printf -v ALL_CMDS "%q" "$CMDS"

  FINAL_CMD="background.sh bash -c $ALL_CMDS"

  echo "$FINAL_CMD"
  eval "$FINAL_CMD"
fi


# Open 'meld' to manually verify all backup contents in $DEST1.
if false; then
  CMD="meld \"/$SRC1\" \"$$DEST1\" &"
  echo "$CMD"
  eval "$CMD"
fi

# Open 'meld' to manually verify all backup contents in $DEST2.
if false; then
  CMD="meld \"/$SRC2\" \"$$DEST2\" &"
  echo "$CMD"
  eval "$CMD"
fi
