#!/bin/bash

# Script version 1.00
#
# Copyright (c) 2024 R. Diez - Licensed under the GNU AGPLv3

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


# Negative integers are OK here.
# However, we could check that the string is not too long,
# otherwise Bash seems to truncate the integer value.

check_is_integer ()
{
  local STR="$1"
  local ERR_MSG_PREFIX="$2"

  local IS_NUMBER_REGEX='^-?[0-9]+$'

  if ! [[ $STR =~ $IS_NUMBER_REGEX ]] ; then
    abort "${ERR_MSG_PREFIX}String \"$STR\" is not an integer."
  fi
}


cmd_wrapper ()
{
  set -o errexit
  set -o nounset
  set -o pipefail

  eval "$CMD"

  if false; then
    echo "Test output to stderr." >&2
  fi

  if false; then
    exit 123
  fi
}


# ------ Entry Point (only by convention) ------

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. This script only takes one argument with a date like 2024-10-21."
fi

declare -r REFERENCE_DATE="$1"


declare -r DDIFF_TOOL="dateutils.ddiff"  # aka datediff

verify_tool_is_installed "$DDIFF_TOOL" "dateutils"


# Parse the date.
#
# Date formats recognised at the moment:
# - Spanish and English date format.               Example: 21/10/2024
# - German date format.                            Example: 21.10.2024
# - The date format %Y-%m-%d is always recognised. Example: 2024-10-21
#
# The following dateutils.ddiff output format does not do the job well: "%w week(s) %d day(s)"
# It does not handle negative or zero values properly, and it shows "0 week(s)" instead of leaving it out.
# Therefore, just have dateutils.ddiff output the number of days from today, which may be negative,
# and build the output message later on this script.

printf -v CMD \
       "%q  --input-format=%q  --input-format=%q  --format=%q -- %q today" \
       "$DDIFF_TOOL" \
       "%d.%m.%Y" \
       "%d/%m/%Y" \
       "%d" \
       "$REFERENCE_DATE"

if false; then
  echo "$CMD"
fi


# The following convoluted trick captures stdout and stderr to different variables.

# shellcheck disable=SC2030
eval "$({ CAPTURED_STDERR=$({ CAPTURED_STDOUT=$(cmd_wrapper); CMD_EXIT_CODE=$?; } 2>&1; declare -p CAPTURED_STDOUT CMD_EXIT_CODE >&2); declare -p CAPTURED_STDERR; } 2>&1)"

if false; then
  # shellcheck disable=SC2031
  echo "Command exit code: $CMD_EXIT_CODE"
fi


# shellcheck disable=SC2031
if (( CMD_EXIT_CODE != 0 )); then

  # In case of error, do not print the captured stdout, because it will be
  # the normal "Usage: xxx" help text, which is very long.
  # I actually reported a bug about this annoyance:
  #   Improve ddiff error behaviour
  #   https://github.com/hroptatyr/dateutils/issues/162

  # If ddiff cannot parse the date, the error is not quite right:
  #   ddiff: Error: reference DATE must be specified
  # I actually reported a bug about this annoyance (it is the same bug report mentioned above):
  #   Improve ddiff error behaviour
  #   https://github.com/hroptatyr/dateutils/issues/162
  # We could filter that error message here and replace it with something better.

  if [ -n "$CAPTURED_STDERR" ]; then
    echo "Error parsing the date: $CAPTURED_STDERR" >&2
  else
    echo "Error parsing the date." >&2
  fi

  # shellcheck disable=SC2031
  exit "$CMD_EXIT_CODE"

fi


if false; then
  # shellcheck disable=SC2031
  echo "CAPTURED_STDOUT: $CAPTURED_STDOUT"
fi


# Convert the captured text to an integer.

# shellcheck disable=SC2031
check_is_integer "$CAPTURED_STDOUT" "Error parsing the output from $DDIFF_TOOL: "

declare -i DAY_COUNT

if false; then
  # The 10# prefix would prevent anything with leading zeros being treated as an octal value,
  # but then we would need to move an eventual '-' prefix for negative values in front of the 10# prefix.

  # shellcheck disable=SC2031
  DAY_COUNT=$(( 10#$CAPTURED_STDOUT ))
else
  # shellcheck disable=SC2031
  DAY_COUNT=$(( CAPTURED_STDOUT ))
fi


if (( DAY_COUNT == 0 )); then

  echo "$REFERENCE_DATE is today's date."

else

  if (( DAY_COUNT < 0 )); then
    DAY_COUNT=$(( - DAY_COUNT ))
    declare -r PREFIX=""
    declare -r SUFFIX2=" until $REFERENCE_DATE"
  else
    # Alternative message: "10 days have passed since 2024-10-21."
    # That way, the date position would be the same for past and future dates.
    declare -r PREFIX="$REFERENCE_DATE was "
    declare -r SUFFIX2=" ago"
  fi

  STR=""
  SUFFIX=""

  if (( DAY_COUNT >= 7 )); then

    declare -r -i WEEK_COUNT="$(( DAY_COUNT / 7 ))"

    if (( WEEK_COUNT == 1 )); then
      STR+="1 week"
    else
      STR+="$WEEK_COUNT weeks"
    fi

    SUFFIX+=" ($DAY_COUNT days)"

    DAY_COUNT="$(( DAY_COUNT % 7 ))"

    if (( DAY_COUNT != 0 )); then
      STR+=" and "
    fi
  fi

  if (( DAY_COUNT == 1 )); then
    STR+="1 day"
  elif (( DAY_COUNT != 0 )) || [ -z "$STR" ]; then
    # The message "0 days" will actually never be output, because there is
    # a check for 0 days before this code, in order to says that it is today's date.
    STR+="$DAY_COUNT days"
  fi

  echo "${PREFIX}${STR}${SUFFIX}${SUFFIX2}."

fi
