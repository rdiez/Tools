#!/bin/bash

# This example script shows how to implement a notification e-mail
# when RDChecksum detects file changes. See section "DETECTING OFFLINE FILE CHANGES"
# in RDChecksum's help text for more information.
#
# You will need to modify some variables in this script first, search for
# "Review and amend the following variables" below.
#
# You probably want to run this script automatically at regular intervals.
#
# Copyright (c) 2022-2024 R. Diez - Licensed under the GNU AGPLv3
#
# Example script version 1.02.

set -o errexit
set -o nounset
set -o pipefail


declare -a ALL_WATCHED_DIRS
declare -a ALL_DATA_DIRS   # These directories must already exist.
declare -a ALL_MAIL_TITLES
declare -a ALL_RDCHECKSUM_ARGS  # Each string just gets concatenated to the command, so you need to manually quote for Bash.


# ----- Review and amend the following variables ------

# This script expects GNU Mail, which lives in Ubuntu/Debian package mailutils.
# You may need to remove package 'bsd-mailx' first.
# You will probably have to configure GNU Mail beforehand,
# or install a local mail server like Postfix.
declare -r MAIL_TOOL="mail"

# If rdchecksum.pl is not in the PATH, then specify an absolute path here.
declare -r PATH_TO_RDCHECKSUM="rdchecksum.pl"

declare -r MAIL_RECIPIENT="user@example.com"
declare -r MAIL_MAX_LINE_COUNT=100

# We will generate and update all metadata under this directory.
declare -r FILE_CHANGE_DETECTION_DATA_BASE_DIR="$HOME/some/data/path"

ALL_WATCHED_DIRS+=( "$HOME/some/path1" )
# This data directory must already exist.
ALL_DATA_DIRS+=( "$FILE_CHANGE_DETECTION_DATA_BASE_DIR/path1" )
ALL_MAIL_TITLES+=( "Offline File Change Notification 1" )
# Option '--checksum-type=none' is for a quick, best-effort approach,
# see RDChecksum's documentation for an alternative with '--always-checksum' instead.
ALL_RDCHECKSUM_ARGS+=( "--checksum-type=none --no-progress-messages" )

ALL_WATCHED_DIRS+=( "$HOME/some/path2" )
ALL_DATA_DIRS+=( "$FILE_CHANGE_DETECTION_DATA_BASE_DIR/path2" )
ALL_MAIL_TITLES+=( "Offline File Change Notification 2" )
# With option --exclude='/\z' we do not recurse into subdirectories.
# We need to manually quote each problematic argument for Bash.
printf -v EXCLUDE_ARG "%q" "--exclude=/\\z"
ALL_RDCHECKSUM_ARGS+=( "--checksum-type=none --no-progress-messages $EXCLUDE_ARG" )

# ----- You probably will not need to modify anything below this point ------


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


declare -r LF=$'\n'

SendMail ()
{
  local -r RECIPIENT="$1"
  local -r TITLE="$2"
  local -r BODY="$3"

  local CMD
  printf -v CMD \
         "%q -s %q -- %q" \
         "$MAIL_TOOL" \
         "$TITLE" \
         "$RECIPIENT"

  echo "$CMD"
  eval "$CMD" <<< "$BODY"
}


ProcessDir ()
{
  local -r WATCHED_DIR="$1"
  local -r DATA_DIR="$2"
  local -r MAIL_TITLE="$3"
  local -r RDCHECKSUM_ARGS="$4"

  echo "Checking $WATCHED_DIR ..."

  pushd "$DATA_DIR" >/dev/null

  local -r UPDATE_LOG_FILENAME="update.log"
  local -r CHECKSUM_FILENAME="FileChecksums.txt"

  if [ -f "$CHECKSUM_FILENAME" ]; then

    local CMD

    printf -v CMD \
           "%q %s --update --checksum-file=%q -- %q >%q" \
           "$PATH_TO_RDCHECKSUM" \
           "$RDCHECKSUM_ARGS" \
           "$CHECKSUM_FILENAME" \
           "$WATCHED_DIR" \
           "$UPDATE_LOG_FILENAME"

    echo "$CMD"

    set +o errexit
    eval "$CMD"
    local EXIT_CODE="$?"
    set -o errexit

    if (( EXIT_CODE == 1 )); then

      local FIRST_LOG_LINES

      FIRST_LOG_LINES="$(head --lines="$MAIL_MAX_LINE_COUNT" -- "$UPDATE_LOG_FILENAME")"

      local MAIL_BODY=""

      MAIL_BODY+="First $MAIL_MAX_LINE_COUNT lines of the update log:${LF}${LF}"

      MAIL_BODY+="$FIRST_LOG_LINES"

      SendMail "$MAIL_RECIPIENT" "$MAIL_TITLE" "$MAIL_BODY"

      echo "Finished - notification e-mail sent."

    elif (( EXIT_CODE == 0 )); then

      echo "Finished - no file changes detected."

    else

      exit $EXIT_CODE

    fi

  else

    echo "The watched directory has never been scanned. Performing a first scan."

    local CMD

    printf -v CMD \
           "%q %s --create --checksum-file=%q -- %q >%q" \
           "$PATH_TO_RDCHECKSUM" \
           "$RDCHECKSUM_ARGS" \
           "$CHECKSUM_FILENAME" \
           "$WATCHED_DIR" \
           "$UPDATE_LOG_FILENAME"

    echo "$CMD"
    eval "$CMD"

  fi

  popd >/dev/null
}


# ------ Entry Point (only by convention) ------

if (( $# != 0 )); then
  abort "Invalid command-line arguments."
fi


declare -i ALL_WATCHED_DIRS_ELEM_COUNT="${#ALL_WATCHED_DIRS[@]}"
declare -i ALL_DATA_DIRS_ELEM_COUNT="${#ALL_DATA_DIRS[@]}"
declare -i ALL_MAIL_TITLES_ELEM_COUNT="${#ALL_MAIL_TITLES[@]}"
declare -i ALL_RDCHECKSUM_ARGS_ELEM_COUNT="${#ALL_RDCHECKSUM_ARGS[@]}"

if (( ALL_WATCHED_DIRS_ELEM_COUNT != ALL_DATA_DIRS_ELEM_COUNT )); then
  abort "Array ALL_DATA_DIRS has $ALL_DATA_DIRS_ELEM_COUNT element(s), which does not match the $ALL_WATCHED_DIRS_ELEM_COUNT element(s) of array ALL_WATCHED_DIRS."
fi

if (( ALL_WATCHED_DIRS_ELEM_COUNT != ALL_MAIL_TITLES_ELEM_COUNT )); then
  abort "Array ALL_MAIL_TITLES has $ALL_MAIL_TITLES_ELEM_COUNT element(s), which does not match the $ALL_WATCHED_DIRS_ELEM_COUNT element(s) of array ALL_WATCHED_DIRS."
fi

if (( ALL_WATCHED_DIRS_ELEM_COUNT != ALL_RDCHECKSUM_ARGS_ELEM_COUNT )); then
  abort "Array ALL_RDCHECKSUM_ARGS has $ALL_RDCHECKSUM_ARGS_ELEM_COUNT element(s), which does not match the $ALL_WATCHED_DIRS_ELEM_COUNT element(s) of array ALL_WATCHED_DIRS."
fi


for (( INDEX = 0 ; INDEX < ALL_WATCHED_DIRS_ELEM_COUNT; ++INDEX )); do

  if (( INDEX != 0 )); then
    echo
  fi

  ProcessDir "${ALL_WATCHED_DIRS[$INDEX]}" \
             "${ALL_DATA_DIRS[$INDEX]}"    \
             "${ALL_MAIL_TITLES[$INDEX]}"  \
             "${ALL_RDCHECKSUM_ARGS[$INDEX]}"
done
