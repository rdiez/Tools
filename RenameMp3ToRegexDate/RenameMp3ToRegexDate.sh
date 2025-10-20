#!/bin/bash

# The MP3 podcasts from the German public broadcaster WDR 5 used to have sensible filenames,
# but nowadays (as of July 2024) they are named something like 3104403_57032996.mp3
# or 3146466_58228694.mp3, so that you do not easily see the recording dates or titles.
# Furthermore, the "Recorded date" tag inside the files has only the year,
# with neither month nor day of the month.
# One such podcast is "WDR 5 Das Wirtschaftsmagazin".
#
# However, the date is usually inside the "Track name" tag, appended as a suffix like "(12.07.2024)".
#
# This script renames the files to their track names, but with the date as a prefix.
# The date is captured with a regular expression. I could not figure out
# how to do all that with lltag alone, so that is why I wrote this script.
#
# Any invalid characters under Windows or FAT32 are replaced,
# so that you can copy your MP3 files to any USB memory stick or MP3 player without worries.
#
# You may find the scanning and renaming techniques implemented in this script useful,
# even if your particular scenario is somewhat different.
#
# Script version 1.02
#
# Copyright (c) 2024-2025 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  if is_tool_installed "$TOOL_NAME"; then
    return
  fi

  local ERR_MSG="Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager."

  if [[ $DEBIAN_PACKAGE_NAME != "" ]]; then
    ERR_MSG+=" For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
  fi

  abort "$ERR_MSG"
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


# I could not use tool lltag because some international characters in the track names were not output correctly.
declare -r USE_LLTAG=false
declare -r LLTAG_TOOL_NAME="lltag"

if $USE_LLTAG; then
  verify_tool_is_installed "$LLTAG_TOOL_NAME" "lltag"
fi


declare -r USE_EXIFTOOL=true
declare -r EXIFTOOL_TOOL_NAME="exiftool"

if $USE_EXIFTOOL; then
  verify_tool_is_installed "$EXIFTOOL_TOOL_NAME" "libimage-exiftool-perl"
fi


declare -r TITLE_REGEX='^Title[[:blank:]]+(.+)$'

declare -r ISO_DATE_SUFFIX=" - "

# Example title: Blah blah...  (21.04.2024)
# Separate the "Blah blah..." (capture 1) from the date (captures 3, 4 and 5).
declare -r SEPARATE_DATE_REGEX="^(.+)[[:blank:]]+\(([[:digit:]][[:digit:]])\.([[:digit:]][[:digit:]])\.([[:digit:]][[:digit:]][[:digit:]][[:digit:]])\)\$"


# The '[' and ']' bracket characters are interpreted by the regular expression engine
# to build a group with the characters inside, and '\' must be doubled or it will not match.
# For other similar character sets, search for 'sanitised' in other Bash scripts in the same repository.
declare -r INVALID_FILENAME_CHARS_REGEX='[\\/:*?"<>|]'


echo "Scanning directory \"$SRC_DIR\"..."

pushd "$SRC_DIR" >/dev/null

shopt -s nullglob
shopt -s nocaseglob

declare -r MP3_EXTENSION=".mp3"

declare -a ALL_FILENAMES_IN_DIR
ALL_FILENAMES_IN_DIR=( *"$MP3_EXTENSION" )

declare -i FILE_COUNT=0

for FILENAME in "${ALL_FILENAMES_IN_DIR[@]}"; do

  FILE_COUNT=$(( FILE_COUNT + 1 ))

  if (( FILE_COUNT != 1 )); then
    echo
  fi

  echo "Processing file: $FILENAME"

  if $USE_LLTAG; then

    printf -v CMD \
           "%q --id3v2  --show-tags title -- %q" \
           "$LLTAG_TOOL_NAME" \
           "$FILENAME"
  fi

  if $USE_EXIFTOOL; then

    printf -v CMD \
           "%q -tab -Title -- %q" \
           "$EXIFTOOL_TOOL_NAME" \
           "$FILENAME"
  fi

  echo "$CMD"
  TITLE_CMD_OUTPUT=$(eval "$CMD")

  if false; then
    echo "Title command output: $TITLE_CMD_OUTPUT"
  fi

  if ! [[ $TITLE_CMD_OUTPUT =~ $TITLE_REGEX ]] ; then
    ERR_MSG=""
    ERR_MSG+="Could not extract the title from the command's output:"
    ERR_MSG+=$'\n'
    ERR_MSG+="$TITLE_CMD_OUTPUT"
    abort "$ERR_MSG"
  fi

  TITLE="${BASH_REMATCH[1]}"

  if false; then
    echo "Title extracted: $TITLE"
  fi

  if ! [[ $TITLE =~ $SEPARATE_DATE_REGEX ]] ; then
    ERR_MSG=""
    ERR_MSG+="Could not separate the date suffix from the extracted title:"
    ERR_MSG+=$'\n'
    ERR_MSG+="$TITLE"
    abort "$ERR_MSG"
  fi

  TITLE_WITHOUT_DATE=${BASH_REMATCH[1]}
  DAY=${BASH_REMATCH[2]}
  MONTH=${BASH_REMATCH[3]}
  YEAR=${BASH_REMATCH[4]}

  if false; then
    echo "Title without date: $TITLE_WITHOUT_DATE"
    echo "Date found: $DAY.$MONTH.$YEAR"
  fi

  # Replace some characters which are invalid under Windows or FAT32 with a hyphen ('-'),
  # so that you can copy your MP3 files to any USB memory stick or MP3 player without worries.
  # See INVALID_FILENAME_CHARS_REGEX for the list of replaced characters.
  # There may be some more such characters to replace,
  # and there are some other rules which could be honoured here,
  # like no leading or trailing spaces, and no trailing dot.
  TITLE_WITHOUT_DATE=${TITLE_WITHOUT_DATE//$INVALID_FILENAME_CHARS_REGEX/-}

  # We use the ISO 8601 date format, which looks like this: 2024-07-13
  NEW_FILENAME="$YEAR.$MONTH.$DAY$ISO_DATE_SUFFIX$TITLE_WITHOUT_DATE$MP3_EXTENSION"

  MOVE_CMD="mv -- ${FILENAME@Q}  ${DEST_DIR_ABS@Q}/${NEW_FILENAME@Q}"

  echo "$MOVE_CMD"
  eval "$MOVE_CMD"

done

if (( FILE_COUNT == 0 )); then
  echo "No files found to process."
else
  echo
  echo "$FILE_COUNT file(s) processed."
fi

popd >/dev/null
