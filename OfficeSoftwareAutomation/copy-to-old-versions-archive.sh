#!/bin/bash

# This script creates an "Archived" subdirectory where the given file resides and copies
# the file there. The current date and time are appended to the archived filename.
#
# This is useful in order to manually create backup copies. If you want to fully automate
# the process, consider using a tool like 'rotate-backups', which can help you trim excessive copies.
#
# Specify command-line option '--move' in order to move the file, instead of copying it.
#
# Usage example:
#   copy-to-old-versions-archive.sh --move -- myfile.txt
#
# Script 'move-to-old-versions-archive.sh' is a simple wrapper which runs this script
# with the "--move" argument prepended.
#
# Set environment variable ARCHIVED_SUBDIR_NAME beforehand if you want to use a different
# name for the "Archived" subdirectories.
#
# If ARCHIVED_SUBDIR_NAME has several subdirectory names separated with colons (':'),
# this script checks first whether any of the given subdirectories exist.
# Otherwise, the first one is automatically created.
# This is to support several languages. For example, the following supports English, German and Spanish:
#   export ARCHIVED_SUBDIR_NAME="Archived:Archiviert:Archivado"
#
# Script version 1.08
#
# Copyright (c) 2017-2023 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit 1
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
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
  echo "Running the self-tests..."
  calculate_dest_filename_self_tests
  echo "Self-tests finished."
  exit 0
fi


invalid_command_line_arguments ()
{
  abort "Invalid number of command-line arguments. See this script's source code for more information."
}


# ------ Entry Point (only by convention) ------

if (( $# < 1 )); then
  invalid_command_line_arguments
fi

if [[ "$1" = "--move" ]]; then

  declare -r SHOULD_MOVE=true
  shift

else

  declare -r SHOULD_MOVE=false

fi

if (( $# < 1 )); then
  invalid_command_line_arguments
fi

if [[ "$1" = "--" ]]; then
  shift
fi

if (( $# != 1 )); then
  invalid_command_line_arguments
fi


FILENAME_SRC_ARG="$1"


FILENAME_SRC_ABS="$(readlink --canonicalize --verbose -- "$FILENAME_SRC_ARG")"

if ! [ -f "$FILENAME_SRC_ABS" ]; then
  abort "File \"$FILENAME_SRC_ABS\" does not exist or is not a regular file."
fi


DIRNAME_SRC_ABS="${FILENAME_SRC_ABS%/*}"

# We do not need to add a special case for the root directory, because
# we will be appending a '/' first thing later on.
#   if [[ $DIRNAME_SRC_ABS = "" ]]; then
#     DIRNAME_SRC_ABS="/"
#   fi


FILENAME_SRC_WITHOUT_DIR="${FILENAME_SRC_ABS##*/}"


declare -r ARCHIVED_SUBDIR_NAME_ENV_VAR_NAME="ARCHIVED_SUBDIR_NAME"

if is_var_set "$ARCHIVED_SUBDIR_NAME_ENV_VAR_NAME"; then

  declare -a PARSED_SUBDIRS

  # The alternative to 'printf' below would be to use a Bash "Here String" (with <<<),
  # but that would add a new-line character.

  readarray -d ":" -t PARSED_SUBDIRS < <( printf "%s" "${!ARCHIVED_SUBDIR_NAME_ENV_VAR_NAME}" )

  # Remove any empty entries, so that something like "A::B" yields 'A' und 'B'.
  declare -a ARCHIVE_SUBDIRS=()

  for SUBDIR in "${PARSED_SUBDIRS[@]}"; do
    if [ -n "$SUBDIR" ]; then
      ARCHIVE_SUBDIRS+=("$SUBDIR")
    fi
  done

  if (( "${#ARCHIVE_SUBDIRS[@]}" < 1 )); then
    abort "Environment variable $ARCHIVED_SUBDIR_NAME_ENV_VAR_NAME has an invalid value."
  fi

else

  declare -a ARCHIVE_SUBDIRS=("Archived")

fi


DIRNAME_DEST_ABS=""

for ARCHIVED_SUBDIR_NAME in "${ARCHIVE_SUBDIRS[@]}"; do

  if [ -d "$DIRNAME_SRC_ABS/$ARCHIVED_SUBDIR_NAME" ]; then
    DIRNAME_DEST_ABS="$DIRNAME_SRC_ABS/$ARCHIVED_SUBDIR_NAME"
    break
  fi

done

if [ -z "$DIRNAME_DEST_ABS" ]; then

  ARCHIVED_SUBDIR_NAME="${ARCHIVE_SUBDIRS[0]}"

  DIRNAME_DEST_ABS="$DIRNAME_SRC_ABS/$ARCHIVED_SUBDIR_NAME"

  mkdir --parents -- "$DIRNAME_DEST_ABS"

fi


printf -v DATE_SUFFIX "%(%Y-%m-%d-%H%M%S)T"

# The "last modified date" in a filesystem is not fixed and is unreliable for archival purposes,
# therefore many filenames already have a date inside. If we just append another date,
# it is no longer clear which date means what. Therefore, instead of just appending
# something like "2024-01-28", append "Archived-2024-01-28". This way, it is clear
# when the document was created and when it is archived.
declare -r SHOULD_PREPEND_ARCHIVED_SUBDIR_NAME_TO_DATE_SUFFIX=true

if $SHOULD_PREPEND_ARCHIVED_SUBDIR_NAME_TO_DATE_SUFFIX; then

  DATE_SUFFIX="$ARCHIVED_SUBDIR_NAME-$DATE_SUFFIX"

fi


RESPECT_FILE_EXTENSION=true

calculate_dest_filename "$FILENAME_SRC_WITHOUT_DIR"

declare -r FILENAME_DEST_ABS="$DIRNAME_DEST_ABS/$FILENAME_DEST"


declare -r SHOULD_PRINT_MSG=true

if $SHOULD_MOVE; then

  mv -- "$FILENAME_SRC_ABS" "$FILENAME_DEST_ABS"

  if $SHOULD_PRINT_MSG; then
    echo "File \"$FILENAME_SRC_ABS\" moved to archive"
    echo "  as \"$FILENAME_DEST_ABS\"."
  fi

else

  cp -- "$FILENAME_SRC_ABS" "$FILENAME_DEST_ABS"

  if $SHOULD_PRINT_MSG; then
    echo "File \"$FILENAME_SRC_ABS\" copied to archive"
    echo "  as \"$FILENAME_DEST_ABS\"."
  fi

fi
