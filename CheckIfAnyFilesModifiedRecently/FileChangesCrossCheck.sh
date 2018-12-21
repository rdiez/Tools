#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r CHECK_SCRIPT="./CheckIfAnyFilesModifiedRecently.sh"

declare -r MOUNT_POINT_BASE="/home/rdiez/MountPoints"
declare -r SOME_BASE_DIR="$MOUNT_POINT_BASE/SomeDir"

declare -r -i ONE_WEEK_IN_MINUTES="$(( 7 * 24 * 60 ))"


check_dir ()
{
  local DIR="$1"
  local MINUTES="$2"

  printf "Checking \"%s\" ...\\n"  "$DIR"

  "$CHECK_SCRIPT" --since-minutes="$MINUTES" -- "$DIR"
}


check_dir  "$SOME_BASE_DIR/Dir1"  "$ONE_WEEK_IN_MINUTES"
check_dir  "$SOME_BASE_DIR/Dir2"  "$ONE_WEEK_IN_MINUTES"

echo "All checks finished."
