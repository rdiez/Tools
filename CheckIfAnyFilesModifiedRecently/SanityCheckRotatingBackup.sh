#!/bin/bash

# Example script to sanity-check rotating backups.
#
# Copyright (c) 2018-2021 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r CHECK_SCRIPT="./CheckIfAnyFilesModifiedRecently.sh"

declare -r SOME_BASE_DIR="$HOME/Some/Dir"

declare -r -i ONE_WEEK_IN_MINUTES="$(( 7 * 24 * 60 ))"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


check_if_any_files_modified_recently ()
{
  local -r    DIR="$1"
  local -r -i MINUTES="$2"

  printf "Checking if any files modified recently in \"%s\" ...\\n"  "$DIR"

  "$CHECK_SCRIPT" --since-minutes="$MINUTES" -- "$DIR"
}


get_dir_file_count ()
{
  local -r DIR="$1"

  shopt -s nullglob  # In case the directory is empty.

  # We are not including hidden files.
  #   shopt -s dotglob

  local -a ALL_FILENAMES

  pushd "$DIR" >/dev/null

  ALL_FILENAMES=( * )

  popd >/dev/null

  if false; then
    echo "Files found: ${ALL_FILENAMES[*]}"
  fi

  DIR_FILE_COUNT="${#ALL_FILENAMES[@]}"
}


# Checks whether any files have been modified recently,
# and also if the number of files lies within the limits.

check_rotating_backup ()
{
  local -r DIR="$1"
  local -r -i MINUTES="$2"
  local -r -i MIN_FILE_COUNT="$3"
  local -r -i MAX_FILE_COUNT="$4"


  printf "Checking file count in \"%s\" ...\\n"  "$DIR"

  get_dir_file_count "$DIR"

  if (( DIR_FILE_COUNT < MIN_FILE_COUNT )); then
    abort "Error in directory \"$DIR\": the file and directory count is $DIR_FILE_COUNT, but the minimum is $MIN_FILE_COUNT."
  fi

  if (( DIR_FILE_COUNT > MAX_FILE_COUNT )); then
    abort "Error in directory \"$DIR\": the file and directory count is $DIR_FILE_COUNT, but the maximum is $MAX_FILE_COUNT."
  fi


  check_if_any_files_modified_recently "$DIR" "$MINUTES"
}


check_if_any_files_modified_recently  "$SOME_BASE_DIR/Dir1"  "$ONE_WEEK_IN_MINUTES"
check_if_any_files_modified_recently  "$SOME_BASE_DIR/Dir2"  "$ONE_WEEK_IN_MINUTES"

check_rotating_backup  "$SOME_BASE_DIR/Dir3"  "$ONE_WEEK_IN_MINUTES"   10   99
check_rotating_backup  "$SOME_BASE_DIR/Dir4"  "$ONE_WEEK_IN_MINUTES"  100  999

echo "All checks finished."
