#!/bin/bash

# See sibling script stash-index.sh for more information.
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace execution of this script.


declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


if [ $# -ne 0 ]; then
  abort "No command-line arguments are allowed."
fi


# Step 4)
#
# Revert from the working tree all changes that are in the staged index.
#
# Unfortunately, Git is not smart enough to realise that the same changes
# it is restoring to the index are already  present in the working tree.

CMD="git stash show --patch | git apply --reverse"

echo "$CMD"
eval "$CMD"


# Step 5)
#
# Restore the changes to the index.
#
# Unfortunately, '-quiet' does not suppress the "Unstaged changes after reset:" list, at least with Git version 2.15.0 .

CMD="git stash pop --quiet --index"

echo "$CMD"
eval "$CMD"
