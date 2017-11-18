#!/bin/bash

# Stash only the staged changes, and remove those changes from the stage.
#
# This is useful if you are in the middle of a big commit, and you just realised that
# you want to make a small, unrelated commit before the big one.
#
# After the small commit, restore the previous state with the sibling script unstash-index.sh .
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


# POSSIBLE ALTERNATIVE:
#   We could create a temporary commit with the currently-staged changes,
#   then create the unrelated commit, afterwards reorder those 2 commits,
#   and finally restore the originally staged changes.


# Step 1)
#
# Save all changes in the working tree to the stash, including all staged changes.
# Revert the working directory to match the HEAD commit, but keep any staged changes.
# Untracked files are not affected.

CMD="git stash push --quiet --keep-index"

echo "$CMD"
eval "$CMD"


# Step 2)
#
# Stash everything that remains, which is only the staged changes.

CMD="git stash push --quiet --message \"Created by git-stash-index.sh\""

echo "$CMD"
eval "$CMD"


# Step 3)
#
# Restore what we had at the beginning.

CMD="git stash pop --quiet stash@{1}"

echo "$CMD"
eval "$CMD"

# The stash that remains has just those changes were originally staged.

echo
echo "Commit your unrelated changes now, and then run git-unstash-index.sh ."
echo
