#!/bin/bash

# This is the script I use to generate a list of alternate dates like this:
#
#   2025-06-16 Monday    yes
#   2025-06-17 Tuesday   no
#   2025-06-18 Wednesday yes
#   2025-06-19 Thursday  no
#   2025-06-20 Friday    yes
#   2025-06-21 Saturday  no
#   2025-06-22 Sunday    yes
#   2025-06-23 Monday    no
#
# Script version 1.00
#
# Copyright (c) 2025 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
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

if (( $# != 0 )); then
  abort "Invalid number of command-line arguments. This script takes no arguments."
fi


declare -r DATE_TOOL="date"

verify_tool_is_installed "$DATE_TOOL" "coreutils"

# declare -r START_DATE="2025-06-08"  # An ISO 8601 date prevents ambiguity.
# declare -r START_DATE="now"  # 'now' includes the current time too.
declare -r START_DATE="today 00:00:00"

# 24 * 60 * 60 seconds = 1 day
declare -r DATE_DELTA_IN_SECONDS=$(( 24 * 60 * 60 ))

declare -r ITERATION_COUNT=30

declare -r TEXT_YES="yes"
declare -r TEXT_NO="no"

declare -r FIRST_IS_NO=0  # 0=false and 1=true.

# With LC_TIME you can change the the date format and the language of the days of the week. Examples:
#   export LC_TIME="en_US.UTF-8"
#   export LC_TIME="de_DE.UTF-8"
#   export LC_TIME="es_ES.UTF-8"

# Example output: 2025-06-08 Sunday (ISO 8601 date)
# declare -r DATE_TIME_FORMAT="%Y-%m-%d %A"
#
declare -r DATE_TIME_FORMAT="%x %A"


START_DATE_EPOCH=$("$DATE_TOOL" --date="$START_DATE" +%s)
readonly START_DATE_EPOCH

{
  CURRENT_DATE_EPOCH="$START_DATE_EPOCH"

  for (( I = 0; I < ITERATION_COUNT; ++I )); do

    if (( 0 == ( I + FIRST_IS_NO ) % 2 )); then
      TEXT="$TEXT_YES"
    else
      TEXT="$TEXT_NO"
    fi

    printf "%($DATE_TIME_FORMAT)T""\t$TEXT""\n" "$CURRENT_DATE_EPOCH"

    CURRENT_DATE_EPOCH=$(( CURRENT_DATE_EPOCH + DATE_DELTA_IN_SECONDS ))

  done
} | column  --table  --separator $'\t' --output-separator " "
