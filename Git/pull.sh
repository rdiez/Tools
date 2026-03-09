#!/bin/bash

# Script version 1.01.
#
# "git pull" tends to generate unnecessary merge commits.
# This script uses "git fetch" and "git merge --ff-only" to do the same without
# those merge commits. If a "fast forward" is not possible, you will get an error
# and then you will have to manually merge.
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


# "git fetch" may download too much. Given the default configuration:
#   [remote "origin"]
#   fetch = +refs/heads/*:refs/remotes/origin/*
# All remote branches will be downloaded.
# If your network connection is slow, you may want to restrict the branches you download.
# Perhaps you only need to fetch the master/main branch most of the time, like this:
#   git fetch origin master

CMD="git fetch"

echo
echo "$CMD"
eval "$CMD"


# "git merge" only merges the current branch.
#
# Switch "--ff-only" prevents unnecessary merge commits that tend to clutter the Git history while providing no real value.

CMD="git merge --ff-only FETCH_HEAD"

echo
echo "$CMD"
eval "$CMD"
