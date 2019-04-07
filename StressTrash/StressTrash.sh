#!/bin/bash

# Some Linux distributions, like Ubuntu MATE 18.04.2, do not enforce any trash limits.
# Sending a file to the trash bin does not release disk space.
# You would expect that the system automatically deletes old trashed files
# as needed, but it just does not happen on some distributions.
#
# This script creates and trashes files in a loop, in order to stress
# the trash bin and check whether your system enforces its trash limits.
#
# In the case of Ubuntu MATE 18.04.2, when the disk fills up, you do get
# the following dialog box:
#
#   This computer has only x,x GB disk space remaining.
#
#   You can free up disk space by emptying the Trash, removing unused
#   programs or files, or moving files to an external disk.
#
# However, the stress script carries on and fills up the disk
# until there are no free bytes left. That is actually an undesirable
# situation, because full disks tend to cause trouble everywhere.
# For example, choosing the "empty trash" option in the dialog box above
# does not actually work, probably because the disk is full.
#
# This script uses tool 'trash', so remember to install package 'trash-cli' beforehand.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


# ------- Entry point -------

if (( $# != 0 )); then
  abort "Invalid number of command-line arguments."
fi

declare -r -i FILE_SIZE_KB=$(( 1 * 1024 * 1024 ))

declare -i ITERATION_COUNTER=1

while true; do

  printf -v FILENAME  "StressTrashTestFile-%06d.bin"  "$ITERATION_COUNTER"

  echo "Creating and deleting file $FILENAME ..."

  dd  bs=1024  count="$FILE_SIZE_KB"  if=/dev/urandom  of="$FILENAME"  status="none"

  trash "$FILENAME"

  ITERATION_COUNTER=$(( ITERATION_COUNTER + 1 ))

done
