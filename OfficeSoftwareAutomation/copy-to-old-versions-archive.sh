#!/bin/bash

# This script creates an "Archived" subdirectory where the given file resides and copies
# the file there. The current date and time are appended to the archived filename.
#
# Script version 1.0
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r ARCHIVED_SUBDIR_NAME="Archived"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi


FILENAME="$1"


FILENAME_ABS="$(readlink --canonicalize --verbose "$FILENAME")"

if ! [ -f "$FILENAME_ABS" ]; then
  abort "File \"$FILENAME_ABS\" does not exist or is not a regular file."
fi


BASEDIR="${FILENAME_ABS%/*}"

# We do not need to add a special case for the root directory, because
# we will be appending a '/' first thing later on.
#   if [[ $BASEDIR = "" ]]; then
#     BASEDIR="/"
#   fi

FILE_NAME_ONLY="${FILENAME_ABS##*/}"


# We could try to generate an archived copy that has the same file extension.
# That is, we could insert the timestamp before the file extension.
# You can extract the extension with a command like this:
#   FILE_EXTENSION="${FILE_NAME_ONLY##*.}"
# However, it is somewhat tricky to determine what the file extension is.
# Consider the following cases:
#   file
#   file.
#   file.txt
#   file.tar.gz
#   file-version-1.2.3.txt


ARCHIVED_DIRNAME="$BASEDIR/$ARCHIVED_SUBDIR_NAME"

mkdir --parents -- "$ARCHIVED_DIRNAME"


printf -v DATE_SUFFIX "%(%Y-%m-%d-%H%M%S)T"

FILENAME_DEST="$ARCHIVED_DIRNAME/$FILE_NAME_ONLY-$DATE_SUFFIX"

cp -- "$FILENAME_ABS" "$FILENAME_DEST"

if true; then
  echo "File \"$FILENAME_ABS\" archived as \"$FILENAME_DEST\"."
fi
