#!/bin/bash

# This example script shows how to implement a notification e-mail
# when RDChecksum detects file changes. See section "DETECTING OFFLINE FILE CHANGES"
# in RDChecksum's help text for more information, like how to create
# the first checksum file that this script will then update.
#
# You will need to modify some variables in this script first, search for
# "Review and amend the following variables" below.
#
# You probably want to run this script automatically at regular intervals.
#
# Copyright (c) 2022-2024 R. Diez - Licensed under the GNU AGPLv3
#
# Example script version 1.01.

set -o errexit
set -o nounset
set -o pipefail


# ----- Review and amend the following variables ------

# This script expects GNU Mail, which lives in Ubuntu/Debian package mailutils.
# You may need to remove package 'bsd-mailx' first.
# You will probably have to configure GNU Mail beforehand,
# or install a local mail server like Postfix.
declare -r MAIL_TOOL="mail"

declare -r WATCHED_BASE_DIR="$HOME/some/path"

declare -r PATH_TO_RDCHECKSUM="./rdchecksum.pl"

declare -r MAIL_RECIPIENT="user@example.com"
declare -r MAIL_TITLE="Offline File Change Notification"
declare -r MAIL_MAX_LINE_COUNT=100

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


# ------ Entry Point (only by convention) ------

if (( $# != 0 )); then
  abort "Invalid command-line arguments."
fi

declare -r UPDATE_LOG_FILENAME="update.log"

# Option '--checksum-type=none' is for a quick, best-effort approach,
# see RDChecksum's documentation for an alternative with '--always-checksum' instead.

printf -v CMD \
       "%q --update --checksum-type=none --no-progress-messages -- %q >%q" \
       "$PATH_TO_RDCHECKSUM" \
       "$WATCHED_BASE_DIR" \
       "$UPDATE_LOG_FILENAME"

echo "$CMD"

set +o errexit
eval "$CMD"
EXIT_CODE="$?"
set -o errexit

if (( EXIT_CODE == 1 )); then

  FIRST_LOG_LINES="$(head --lines="$MAIL_MAX_LINE_COUNT" -- "$UPDATE_LOG_FILENAME")"

  MAIL_BODY="First $MAIL_MAX_LINE_COUNT lines of the update log:${LF}${LF}"

  MAIL_BODY+="$FIRST_LOG_LINES"

  SendMail "$MAIL_RECIPIENT" "$MAIL_TITLE" "$MAIL_BODY"

  echo "Finished - notification e-mail sent."

elif (( EXIT_CODE == 0 )); then

  echo "Finished - no file changes detected."

else

  exit $EXIT_CODE

fi
