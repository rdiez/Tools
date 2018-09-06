#!/bin/bash
#
# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="GenerateTestBytes-0-to-255.sh"

declare -ri EXIT_CODE_SUCCESS=0
declare -ri EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

Syntax:
  $SCRIPT_NAME [options...] [--] <filename>

Options:
 --help     Displays this help text.
 --stdout   Writes the data to stdout. Do not specify a filename then.
            Beware that this script generates binary output that is not suitable for
            an interactive terminal.
EOF
}


generate_output ()
{
  local -ri REPEAT_COUNT=1
  local -i  i
  local -i  j
  local     TMP

  for (( i = 0; i < REPEAT_COUNT; ++i )); do

    for (( j = 0; j <= 255; ++j )); do

      printf -v TMP  "\\\\x%02X"  "$j"

      # shellcheck disable=SC2059
      printf "$TMP"

    done

  done
}


declare -r INVALID_CMD_ARGS_MSG="Invalid number of command-line arguments. Run this tool with the --help option for usage information."

if (( $# == 0 )); then
  abort "$INVALID_CMD_ARGS_MSG"
fi

declare -r ARG1="$1"

if [[ $ARG1 = "--help" ]]; then
  display_help
  exit $EXIT_CODE_SUCCESS
fi


if [[ $ARG1 = "--stdout" ]]; then

  shift

  if (( $# != 0 )); then

    if [[ $1 != "--" ]]; then
      abort "$INVALID_CMD_ARGS_MSG"
    fi

    shift

  fi

  if (( $# != 0 )); then
    abort "$INVALID_CMD_ARGS_MSG"
  fi

  generate_output

else

  if [[ $ARG1 = "--" ]]; then
    shift
  fi

  if (( $# != 1 )); then
    abort "$INVALID_CMD_ARGS_MSG"
  fi

  declare -r FILENAME="$1"

  {  # Use just a single output redirection to the output file.
     # Otherwise, the data flow does not work well with FIFOs.

    generate_output ;

  } >"$FILENAME"

fi
