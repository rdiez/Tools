#!/bin/bash

# This is the script I use to rename files so that the new filenames contain a timestamp.
# See below for more information about the expected filename format.
#
# You will have to manually edit this script, see the following variables below:
#   DRY_RUN
#   FILENAME_PREFIX
#   NEW_EXTENSION
#
# Example about running this script on many different subdirectories:
#   find  .  -mindepth 1  -maxdepth 1  -type d -print | while read dir; do "$HOME/somedir/RenameWithLastModifiedDate.sh" "$dir"; done
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


collect_filenames ()
{
  local -r L_DIRNAME="$1"
  local -r CMD="$2"

  pushd "$L_DIRNAME" >/dev/null

  COLLECTED_FILENAMES=()

  local FILENAME
  while IFS='' read -r -d '' FILENAME; do

    if false; then
      echo "Filename: $FILENAME"
    fi

    COLLECTED_FILENAMES+=( "$FILENAME" )

  done < <( eval "$CMD" )

  popd >/dev/null

  local -i COLLECTED_FILENAMES_COUNT="${#COLLECTED_FILENAMES[@]}"

  if (( COLLECTED_FILENAMES_COUNT == 0 )); then
    abort "No files to collect found in \"$L_DIRNAME\"."
  fi
}


# ------- Entry point -------

if (( $# != 1 )); then
  abort "This script takes a single command-line argument with a directory name."
fi

declare -r DIRNAME="$1"

declare -r DRY_RUN=true


# The following is designed to rename such filenames:
#   Prefix.txt.bak01  -> Prefix-2019-01-02-010203.txt
#   Prefix.txt.bak02  -> Prefix-2019-01-03-010203.txt
# Note that "PrefixEtc.txt.bak03" will lose the "Etc" part.

declare -r FILENAME_PREFIX="SomeFilenamePrefix"
declare -r EXTENSION_REGEXP="\\.txt\\.bak[0-9]+"
# Alternative with a single filename extension:
#  declare -r EXTENSION_REGEXP="\\.doc"
declare -r NEW_EXTENSION=".doc"

declare -r IS_MATCH_CASE_INSENSITIVE=false


declare -r FILENAME_REGEXP="^$FILENAME_PREFIX.*$EXTENSION_REGEXP\$"

# We could make this regular expression tighter. For example, the first digit of the month can only be 0 or 1.
# Example timestamp: 2019-12-31-081505
declare -r ALREADY_CONTAINS_TIMESTAMP_REGEXP="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]"

printf -v CMD  "find  .  -mindepth 1  -maxdepth 1  -type f  -printf %q"  "%P\\0"

echo "Find cmd: $CMD"

collect_filenames  "$DIRNAME"  "$CMD"


pushd "$DIRNAME" >/dev/null

declare -i RENAMED_FILE_COUNT=0

for FILENAME in "${COLLECTED_FILENAMES[@]}"; do

  if false; then
    echo "Filename: $FILENAME"
  fi

  if $IS_MATCH_CASE_INSENSITIVE; then
    shopt -s nocasematch
  fi

  if ! [[ $FILENAME =~ $FILENAME_REGEXP ]]; then

    if false; then
      echo "Skipping because it does not match the name regular expression: $FILENAME"
    fi

    continue
  fi

  shopt -u nocasematch

  # This is to provide idempotence: do not rename if the name already has a timestamp.
  if [[ $FILENAME =~ $ALREADY_CONTAINS_TIMESTAMP_REGEXP ]]; then

    if false; then
      echo "Skipping because it already contains a timestamp: $FILENAME"
    fi

    continue
  fi

  LAST_MODIFIED="$(date +%F-%H%M%S --reference="$FILENAME")"

  NEW_FILENAME="$FILENAME_PREFIX-$LAST_MODIFIED$NEW_EXTENSION"

  if true; then
    echo "$FILENAME -> $NEW_FILENAME"
  fi

  if ! [[ $NEW_FILENAME =~ $ALREADY_CONTAINS_TIMESTAMP_REGEXP ]]; then
    abort "Internal error: The new filename does not match ALREADY_CONTAINS_TIMESTAMP_REGEXP."
  fi

  # We could check here whether there is already a file with that name.
  # Otherwise, we risk overwriting files.
  # But the chances of that happening are slim. After all, no 2 files should have exactly the same timestamp.

  if ! $DRY_RUN; then
    mv -- "$FILENAME" "$NEW_FILENAME"
  fi

  RENAMED_FILE_COUNT=$(( RENAMED_FILE_COUNT + 1 ))

done


popd >/dev/null

echo "Finished renaming $RENAMED_FILE_COUNT file(s)."
if $DRY_RUN; then
  echo "Dry run - no renaming was actually made."
fi
