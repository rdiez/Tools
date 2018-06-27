#!/bin/bash

# "git pull" tends to generate unnecessary merge commits.
# This script uses "git fetch" and "git merge --ff-only"
# to do the same without those merge commits.
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


# "git fetch" updates only the branch you're on. If you want another branch, or all of them, see "git remote update".

CMD="git fetch"

echo
echo "$CMD"
eval "$CMD"


# Switch "--ff-only" prevents unnecessary merge commits that tend to clutter the Git history while providing no real value.

CMD="git merge --ff-only FETCH_HEAD"

echo
echo "$CMD"
eval "$CMD"
