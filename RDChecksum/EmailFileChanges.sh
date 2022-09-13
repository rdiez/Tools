#!/bin/bash

# This example script shows how to implement a notification e-mail when RDChecksum detects file changes.
# You probably want to run this script at regular intervals.
#
# Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r LF=$'\n'

# This script expects GNU Mail, which lives in Ubuntu/Debian package mailutils.
# You may need to remove package 'bsd-mailx' first.
# You will probably have to configure GNU Mail beforehand,
# or install a local mail server like Postfix.
declare -r MAIL_TOOL="mail"

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


declare -r MAIL_RECIPIENT="user@example.com"
declare -r MAIL_TITLE="Offline File Change Notification"
declare -r MAIL_MAX_LINE_COUNT=100

declare -r BASE_DIR="$HOME/some/path"

declare -r UPDATE_LOG_FILENAME="update.log"

# Option '--checksum-type=none' is for a quick, best-effort approach,
# see RDChecksum's documentation for an alternative with '--always-checksum' instead.

printf -v CMD \
       "./rdchecksum.pl --update --checksum-type=none --no-progress-messages -- %q >%q" \
       "$BASE_DIR" \
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
