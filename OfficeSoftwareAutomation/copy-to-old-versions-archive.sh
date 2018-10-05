#!/bin/bash

# This script creates an "Archived" subdirectory where the given file resides and copies
# the file there. The current date and time are appended to the archived filename.
#
# Set environment variable ARCHIVED_SUBDIR_NAME beforehand if you want to use a different
# name for the "Archived" subdirectories.
#
# Script version 1.04
#
# Copyright (c) 2017-2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r ARCHIVED_SUBDIR_NAME_ENV_VAR_NAME="ARCHIVED_SUBDIR_NAME"
declare -r ARCHIVED_SUBDIR_NAME="${!ARCHIVED_SUBDIR_NAME_ENV_VAR_NAME:-Archived}"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


calculate_dest_filename ()
{
  local FILENAME_WITHOUT_DIR="$1"

  if $RESPECT_FILE_EXTENSION; then

    local FN="${FILENAME_WITHOUT_DIR%.*}"
    local EXT="${FILENAME_WITHOUT_DIR##*.}"

    local REASSEMBLED="$FN.$EXT"

    if false; then
      echo "$FILENAME_WITHOUT_DIR -> $FN - $EXT"
    fi

    if [[ $REASSEMBLED != "$FILENAME_WITHOUT_DIR" || $FN = "" || $EXT = "" ]]; then
      FILENAME_DEST="$FILENAME_WITHOUT_DIR-$DATE_SUFFIX"
    else
      FILENAME_DEST="$FN-$DATE_SUFFIX.$EXT"
    fi

    if false; then
      echo "$FILENAME_WITHOUT_DIR -> $FILENAME_DEST"
      echo
    fi

  else

    FILENAME_DEST="$FILENAME_WITHOUT_DIR-$DATE_SUFFIX"

  fi
}


calculate_dest_filename_test_case ()
{
  local FILENAME_WITHOUT_DIR="$1"
  local EXPECTED_RESULT="$2"

  calculate_dest_filename "$FILENAME_WITHOUT_DIR"

  if [[ $FILENAME_DEST != "$EXPECTED_RESULT" ]]; then
    abort "Failed self-test case: \"$FILENAME_WITHOUT_DIR\" yielded \"$FILENAME_DEST\" instead of \"$EXPECTED_RESULT\"."
  fi
}


calculate_dest_filename_self_tests ()
{
  local DATE_SUFFIX="2018-12-31-204501"

  # In this mode, we simply add the timestamp at the end. For example,
  # "file.txt" becomes "file.txt-2018-12-31-204501" .
  #
  # This is rather inconvenient, because the extension is normally used to determine the file type,
  # so you cannot open the archived files by simply double-clicking on them.
  RESPECT_FILE_EXTENSION=false

  calculate_dest_filename_test_case "file.txt" "file.txt-2018-12-31-204501"


  # In this mode, we try to respect the file extension. For example,
  # "file.txt" becomes "file-2018-12-31-204501.txt" .
  # This does not work well in all cases. For example,
  # in "file.tar.gz", the extension is considered to be ".gz", and not ".tar.gz".
  # In other corner cases it is not clear what the extension should be.
  RESPECT_FILE_EXTENSION=true

  calculate_dest_filename_test_case "file" "file-2018-12-31-204501"
  calculate_dest_filename_test_case "file.txt" "file-2018-12-31-204501.txt"
  calculate_dest_filename_test_case ".file" ".file-2018-12-31-204501"
  calculate_dest_filename_test_case "..file" ".-2018-12-31-204501.file"
  calculate_dest_filename_test_case "file." "file.-2018-12-31-204501"
  calculate_dest_filename_test_case "file.." "file..-2018-12-31-204501"
  calculate_dest_filename_test_case "file..txt" "file.-2018-12-31-204501.txt"
  calculate_dest_filename_test_case "file.7z" "file-2018-12-31-204501.7z"
  calculate_dest_filename_test_case "file.tar.gz" "file.tar-2018-12-31-204501.gz"
  calculate_dest_filename_test_case "file..tar..gz" "file..tar.-2018-12-31-204501.gz"
  calculate_dest_filename_test_case "file-version-1.2.3" "file-version-1.2-2018-12-31-204501.3"
  calculate_dest_filename_test_case "file-version-1.2.3.txt" "file-version-1.2.3-2018-12-31-204501.txt"
}


if false; then
  calculate_dest_filename_self_tests
  exit 0
fi


if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi


FILENAME_SRC_ARG="$1"


FILENAME_SRC_ABS="$(readlink --canonicalize --verbose -- "$FILENAME_SRC_ARG")"

if ! [ -f "$FILENAME_SRC_ABS" ]; then
  abort "File \"$FILENAME_SRC_ABS\" does not exist or is not a regular file."
fi


BASEDIR="${FILENAME_SRC_ABS%/*}"

# We do not need to add a special case for the root directory, because
# we will be appending a '/' first thing later on.
#   if [[ $BASEDIR = "" ]]; then
#     BASEDIR="/"
#   fi


FILENAME_SRC_WITHOUT_DIR="${FILENAME_SRC_ABS##*/}"


# ShellCheck does not support yet the %(%Y...) syntax.
# shellcheck disable=SC2183
printf -v DATE_SUFFIX "%(%Y-%m-%d-%H%M%S)T"

RESPECT_FILE_EXTENSION=true

calculate_dest_filename "$FILENAME_SRC_WITHOUT_DIR"


ARCHIVED_DIRNAME="$BASEDIR/$ARCHIVED_SUBDIR_NAME"

FILENAME_DEST_ABS="$ARCHIVED_DIRNAME/$FILENAME_DEST"

mkdir --parents -- "$ARCHIVED_DIRNAME"

cp -- "$FILENAME_SRC_ABS" "$FILENAME_DEST_ABS"

if true; then
  echo "File \"$FILENAME_SRC_ABS\" archived as \"$FILENAME_DEST_ABS\"."
fi
