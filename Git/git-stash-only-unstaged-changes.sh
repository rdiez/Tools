#!/bin/bash

# Version 1.01.
#
# Stash only the changes in the working files that are not staged.
#
# Those changes are then removed from the working files, like "git stash push" normally does.
#
# This is useful if you have changed a lot of files, and you now want to isolate
# some of the changes or to temporarily unclutter your workspace. So you stage some changes,
# but before committing, you want to temporarily remove any other changes,
# in order to test whether your staged changes compile cleanly.
#
# You could branch, but you generally do not want to clutter your history with temporary branches.
#
# Any command-line arguments to this script are passed to the "git stash push" command
# that ultimately creates the stash from the unstaged changes.
# You would normally specify something like --message "my stash message" , or maybe even --include-untracked .
#
# The functionality that this script implements is often convenient and should actually be part of Git.
# Many people have discussed this the past. For example:
#
# - Stashing only un-staged changes in Git
#   https://stackoverflow.com/questions/7650797/stashing-only-un-staged-changes-in-git/44824325

#
# Copyright (c) 2021 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace execution of this script.


declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


# Check whether the stage is empty, because using this script makes no sense then,
# and it is probably a human error. There is another reason: this script
# creates a temporary commit, but such a commit cannot be created if the stage is empty.

# Option --exit-code is actually implied by --quiet, but I like to be explicit.
CMD="git diff --staged --quiet --exit-code"

echo "$CMD"

set +o errexit
eval "$CMD"
GIT_DIFF_EXIT_CODE="$?"
set -o errexit

case "$GIT_DIFF_EXIT_CODE" in
  0) abort "The stage/index is empty. This is normally a user error.";;
  1) echo "The stage/index is not empty, so carry on.";;
  *) abort "The \"git diff\" command terminated with unexpected exit code $GIT_DIFF_EXIT_CODE.";;
esac


# Step 1)
#
# Create a temporary commit to save the staged changes separately.
#
# Option --no-verify bypasses the pre-commit and commit-msg hooks. This is not a real,
# permanent commit, so no other processing should be done with it.

CMD="git commit --quiet --no-verify --message \"Temporary commit created by git-stash-no-index.sh\""

echo "$CMD"
eval "$CMD"


# Step 2)
#
# Stash everything that remains, which are only the changes that were not staged.

CMD="git stash push"

if (( $# != 0 )); then

  printf -v USER_ARGS  " %q"  "$@"

  CMD+="$USER_ARGS"
fi

echo "$CMD"
eval "$CMD"


# Step 3)
#
# Drop the temporary commit, so that any changes that were staged at the beginning
# (before the temporary commit) are considered as "having changed" again.
#
# "git reset" does not touch the stage by default, so we add option "--soft" in order
# for those changes to be staged. This effectively restores the original stage status.

CMD="git reset --soft --quiet HEAD~1"

echo "$CMD"
eval "$CMD"


echo
echo "Run the usual command \"git stash pop\" later on in order to recover the non-staged changes you just stashed."
echo
