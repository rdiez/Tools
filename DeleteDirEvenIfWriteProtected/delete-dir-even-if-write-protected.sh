#!/bin/bash

# Script version 1.00.
#
# Deletes the given directories with 'rm', even if the directories
# or any subdirectories within are marked as read-only.
#
# That is, this script does a "chmod a+w" beforehand
# on the specified directories and all their subdirectories.
#
# Note that this tool does not handle Access Control Lists yet (see 'setfacl').
#
# In most scenarios it is safer to use 'trash', so that you can undelete
# from the trash bin. However, if you delete large directory trees that way,
# emptying the trash bin later may be quite slow.

# Copyright (c) 2026 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit "$EXIT_CODE_ERROR"
}


# ------ Entry Point (only by convention) ------

if (( $# == 0 )); then
  abort "This script takes the directories to delete as command-line arguments."
fi

for DIR_TO_DELETE in "$@"; do

  if ! [ -d "$DIR_TO_DELETE" ]; then
    abort "Directory \"$DIR_TO_DELETE\" does not exist."
  fi

  # The 'find' command below still works if DIR_TO_DELETE ends with a slash.

  # We need write permissions on the directory and subdirectories in order to delete
  # the complete subtrees.
  #
  # Permissions can be quite complicated. For example, the 'other' group
  # can have write permissions for a particular directory, but the directory's owner may not.
  # And the directory's owner may be another user, not the current one.
  # Rather than trying to calculate the effective permissions,
  # we just grant all users (owner, group, other) write permissions, so that deletion should succeed.
  #
  # We do not use "chmod --recursive", because that would also change the permission on all files.
  # Depending on the number of files, that can be a huge waste of time.
  # In order to delete, we only need write permissions on the directories.

  CMD="find ${DIR_TO_DELETE@Q} -type d ! \( -perm -u=w,g=w,o=w \) -exec chmod a+w '{}' +"

  echo "$CMD"
  eval "$CMD"

  CMD="rm -rf ${DIR_TO_DELETE@Q}"
  echo "$CMD"
  eval "$CMD"

done
