#!/bin/bash

# Version 1.04.
#
# Stash only the staged changes.
#
# Note that Git version 2.35 introduces a new flag for this purpose:
#  git stash --staged
# Therefore, this script may no longer be necessary.
#
# This script removes those staged changes from the stage and from the working files too,
# like "git stash push" normally does.
#
# This is useful if you are in the middle of a big commit, and you just realised that
# you want to make a small, unrelated commit before the big one.
#
# Any command-line arguments to this script are passed to the "git stash push" command
# that ultimately creates the stash from the staged changes.
# You would normally specify something like --message "my stash message" , or maybe even --include-untracked .
#
# The functionality that this script implements is often convenient and should actually be part of Git.
# Many people have discussed this the past. For example:
#
# - Stashing only staged changes in git - is it possible?
#   https://stackoverflow.com/questions/14759748/stashing-only-staged-changes-in-git-is-it-possible
#
# - How do you tell git to stash the index only?
#   https://stackoverflow.com/questions/5281663/how-do-you-tell-git-to-stash-the-index-only
#
# Furthermore, the documentation of "git stash" and option "--keep-index" is misleading.
# This has also been discussed before:
#   Is "git stash save --keep-index" explained correctly in Chapter 7?
#   https://github.com/progit/progit2/issues/822
#
# Copyright (c) 2017-2021 R. Diez - Licensed under the GNU AGPLv3

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
# and it is probably a human error.

# --exit-code is actually implied by --quiet, but I like to be explicit.
CMD="git diff --staged --quiet --exit-code"

echo "$CMD"

set +o errexit
eval "$CMD"
GIT_DIFF_EXIT_CODE="$?"
set -o errexit

case "$GIT_DIFF_EXIT_CODE" in
  0) abort "The stage/index is empty.";;
  1) echo "The stage/index is not empty, so carry on.";;
  *) abort "The \"git diff\" command terminated with unexpected exit code $GIT_DIFF_EXIT_CODE.";;
esac


# POSSIBLE ALTERNATIVE IMPLEMENTATION:
#   We could create a temporary commit with the currently-staged changes,
#   then create the unrelated commit, afterwards reorder those 2 commits,
#   and finally restore the originally staged changes.


# Step 1)
#
# Save all changes in the working tree to the stash, including all staged changes.
# This stash is only temporary and will be removed afterwards.
#
# Revert the working directory to match the HEAD commit, but keep any staged changes.
# Untracked files are not affected.

CMD="git stash push --quiet --keep-index --message \"Temporary stash created by git-stash-index.sh\""

echo "$CMD"
eval "$CMD"


# Step 2)
#
# Stash everything that remains, which are only the staged changes.
# This is the stash that we want to keep.

CMD="git stash push"

if (( $# != 0 )); then

  printf -v USER_ARGS  " %q"  "$@"

  CMD+="$USER_ARGS"
fi

echo "$CMD"
eval "$CMD"


# Step 3)
#
# Restore what we had at the beginning.
# The working files include the changes that were staged, but the stage itself is now empty.

CMD="git stash pop --quiet stash@{1}"

echo "$CMD"
eval "$CMD"


# Step 4)
#
# Remove from the working files all the changes that were staged, because that is what the user
# probably expects when using a stash command.

# "git apply" must run from the repository's root directory, because according to the documentation:
#   "When running from a subdirectory in a repository, patched paths outside the directory are ignored."
# There is no warning or exit code. This is not just user unfriendly, you cannot actually
# use "git apply" safely, because there is no way to detect file path mismatches when creating
# or applying a patch.

CMD="git rev-parse --show-toplevel"

echo "$CMD"

ROOT_DIR="$($CMD)"

echo "Changing to the repository's top-level directory before running \"git apply\":"
echo "  $ROOT_DIR"

pushd "$ROOT_DIR" >/dev/null

CMD="git stash show --patch | git apply --reverse"

echo "$CMD"
eval "$CMD"

popd >/dev/null


# The stash that remains has just the changes that were originally staged.

echo
echo "Commit your unrelated changes now, and then run \"git stash pop --index\" to recover your previous stage/index state."
echo
