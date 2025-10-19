#!/bin/bash

# The MP3 podcasts "Der Tag" from the German public broadcaster "Deutschlandfunk"
# have half-witted filenames like:
#
#   episode_title_dlf_20250102_2000_random_suffix.mp3
#
# I wanted a common prefix followed by the timestamp, so that you can easily
# sort the episodes by source and date. The format should be then:
#
#   dlf_20250102_2000_episode_title_random_suffix.mp3
#
# This script performs such renaming in a robust manner: if it finds filenames
# which do not fit the expected naming format, it will fail.
# This way, you will notice if the podcast changes the filename format,
# instead of the script simply silently stoping to work properly.
#
# Any invalid characters under Windows or FAT32 are replaced,
# so that you can copy your MP3 files to any USB memory stick or MP3 player without worries.
#
# You may find the scanning and renaming techniques implemented in this script useful,
# even if your particular scenario is somewhat different.
#
# Copyright (c) 2025 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


# ------ Entry Point (only by convention) ------

if (( $# != 2 )); then
  abort "Invalid command-line arguments. Please specify <source dir>, <destination dir>"
fi

declare -r SRC_DIR="$1"
declare -r DEST_DIR="$2"


# These tests to check whether the directories exist are not strictly necessary,
# but they generate cleaner error messages.

if [ ! -d "$SRC_DIR" ]; then
  abort "Source directory \"$SRC_DIR\" does not exist."
fi

if [ ! -d "$DEST_DIR" ]; then
  abort "Destination directory \"$DEST_DIR\" does not exist."
fi


DEST_DIR_ABS="$(readlink --canonicalize-existing --verbose -- "$DEST_DIR")"


declare -r DATE_TIME_REGEX="[[:digit:]][[:digit:]][[:digit:]][[:digit:]][[:digit:]][[:digit:]][[:digit:]][[:digit:]]_[[:digit:]][[:digit:]][[:digit:]][[:digit:]]"

declare -r FILENAME_REGEX="^(.+)_dlf_($DATE_TIME_REGEX)_(.+)\$"

# The '[' and ']' bracket characters are interpreted by the regular expression engine
# to build a group with the characters inside, and '\' must be doubled or it will not match.
# For other similar character sets, search for 'sanitised' in other Bash scripts in the same repository.
declare -r INVALID_FILENAME_CHARS_REGEX='[\\/:*?"<>|]'


echo "Scanning directory..."

pushd "$SRC_DIR" >/dev/null

shopt -s nullglob
shopt -s nocaseglob

declare -r MP3_EXTENSION=".mp3"

declare -a ALL_FILENAMES_IN_DIR
ALL_FILENAMES_IN_DIR=( *"$MP3_EXTENSION" )

declare -i FILE_COUNT=0

for FILENAME in "${ALL_FILENAMES_IN_DIR[@]}"; do

  FILE_COUNT=$(( FILE_COUNT + 1 ))

  echo "Processing file: $FILENAME"

  if ! [[ $FILENAME =~ $FILENAME_REGEX ]] ; then
    abort "Filename \"$FILENAME\" has an invalid format."
  fi

  TITLE="${BASH_REMATCH[1]}"
  DATE_TIME="${BASH_REMATCH[2]}"
  SUFFIX="${BASH_REMATCH[3]}"

  NEW_FILENAME="dlf_${DATE_TIME}_${TITLE}_${SUFFIX}"

  # Replace some characters which are invalid under Windows or FAT32 with a hyphen ('-'),
  # so that you can copy your MP3 files to any USB memory stick or MP3 player without worries.
  # See INVALID_FILENAME_CHARS_REGEX for the list of replaced characters.
  # There may be some more such characters to replace,
  # and there are some other rules which could be honoured here,
  # like no leading or trailing spaces, and no trailing dot.
  NEW_FILENAME_SANITISED=${NEW_FILENAME//$INVALID_FILENAME_CHARS_REGEX/-}

  if false; then
    echo "New filename:    $NEW_FILENAME_SANITISED"
  fi

  mv -- "$FILENAME" "$DEST_DIR_ABS/$NEW_FILENAME_SANITISED"

done

if (( FILE_COUNT == 0 )); then
  echo "No files found to process."
else
  echo "$FILE_COUNT file(s) processed."
fi

popd >/dev/null
