#!/bin/bash

# Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r -i EXIT_CODE_ERROR=1

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


quote_and_append_args ()
{
  local -n VAR="$1"
  shift

  local STR

  # Shell-quote all arguments before joining them into a single string.
  printf -v STR  "%q "  "$@"

  # Remove the last character, which is one space too much.
  STR="${STR::-1}"

  if [ -z "$VAR" ]; then
    VAR="$STR"
  else
    VAR+="  $STR"
  fi
}


run_test ()
{
  local CMD="$1"
  local EXPECTED_OUTPUT_FILENAME="$2"

  echo "$CMD"

  set +o errexit
  eval "$CMD $REDIRECT_TO_OUTPUT_FILE"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  if (( CMD_EXIT_CODE != 0 && CMD_EXIT_CODE != 1 )); then
    abort "$PTLINT_NAME failed with exit code $CMD_EXIT_CODE."
  fi

  printf -v CMD \
         "diff --unified=3 -- %q %q" \
         "$EXPECTED_OUTPUT_FILENAME" \
         "$OUTPUT_FILE"

  echo "$CMD"
  set +o errexit
  eval "$CMD"
  local DIFF_EXIT_CODE="$?"
  set -o errexit

  if (( DIFF_EXIT_CODE != 0 )); then
    abort "The test result is not as expected, see the diff output above."
  fi

  if [ -s "$EXPECTED_OUTPUT_FILENAME" ]; then
    local -i EXPECTED_EXIT_CODE=1
  else
    local -i EXPECTED_EXIT_CODE=0
  fi

  if (( CMD_EXIT_CODE != EXPECTED_EXIT_CODE )); then
    abort "The test's exit code of $CMD_EXIT_CODE does not match the expected $EXPECTED_EXIT_CODE."
  fi

  echo
}


if (( $# != 0 )); then
  abort "This script takes no command-line arguments."
fi

declare -r PTLINT_NAME="ptlint.pl"

declare -r THIS_SCRIPT_DIR="$PWD"

declare -r OUTPUT_FILE="$THIS_SCRIPT_DIR/ptlint-output.txt"

printf -v REDIRECT_TO_OUTPUT_FILE  ">%q 2>&1"  "$OUTPUT_FILE"

declare -r PTLINT_TOOL="../../$PTLINT_NAME"


echo "Changing to directory \"$THIS_SCRIPT_DIR/EOL\"..."
pushd "$THIS_SCRIPT_DIR/EOL" >/dev/null
echo

declare -a FILE_LIST=()

FILE_LIST+=( empty-file.txt )
FILE_LIST+=( 1-empty-line-with-LF.txt )
FILE_LIST+=( 1-text-line-with-CRLF.txt )
FILE_LIST+=( 1-text-line-with-LF.txt )
FILE_LIST+=( 1-text-line-without-eol.txt )
FILE_LIST+=( 2-text-lines-with-CRLF-and-LF.txt )
FILE_LIST+=( 2-text-lines-with-LF.txt )

CMD=""
quote_and_append_args CMD "$PTLINT_TOOL"
quote_and_append_args CMD "--eol=consistent"
quote_and_append_args CMD "${FILE_LIST[@]}"

run_test "$CMD" "$THIS_SCRIPT_DIR/EOL/expected-output-eol-consistent.txt"


CMD=""
quote_and_append_args CMD "$PTLINT_TOOL"
quote_and_append_args CMD "--eol=ignore"
quote_and_append_args CMD "${FILE_LIST[@]}"

run_test "$CMD" "$THIS_SCRIPT_DIR/EOL/expected-ouput-empty.txt"


CMD=""
quote_and_append_args CMD "$PTLINT_TOOL"
quote_and_append_args CMD "--eol=only-lf"
quote_and_append_args CMD "${FILE_LIST[@]}"

run_test "$CMD" "$THIS_SCRIPT_DIR/EOL/expected-output-eol-only-lf.txt"


CMD=""
quote_and_append_args CMD "$PTLINT_TOOL"
quote_and_append_args CMD "--eol=only-crlf"
quote_and_append_args CMD "${FILE_LIST[@]}"

run_test "$CMD" "$THIS_SCRIPT_DIR/EOL/expected-output-eol-only-crlf.txt"

popd >/dev/null


echo "Changing to directory \"$THIS_SCRIPT_DIR/TrailingWhitespace\"..."
pushd "$THIS_SCRIPT_DIR/TrailingWhitespace" >/dev/null
echo

CMD=""
quote_and_append_args CMD "$PTLINT_TOOL" "--no-trailing-whitespace" "trailing-whitespace.txt"

run_test "$CMD" "$THIS_SCRIPT_DIR/TrailingWhitespace/expected-ouput-trailing-whitespace.txt"

popd >/dev/null


echo "Changing to directory \"$THIS_SCRIPT_DIR/Tabs\"..."
pushd "$THIS_SCRIPT_DIR/Tabs" >/dev/null
echo

CMD=""
quote_and_append_args CMD "$PTLINT_TOOL" "--no-tabs" "tabs.txt"

run_test "$CMD" "$THIS_SCRIPT_DIR/Tabs/expected-ouput-no-tabs.txt"

popd >/dev/null


echo "Changing to directory \"$THIS_SCRIPT_DIR/NonAscii\"..."
pushd "$THIS_SCRIPT_DIR/NonAscii" >/dev/null
echo

CMD=""
quote_and_append_args CMD "$PTLINT_TOOL" "--only-ascii" "non-ascii.txt"

run_test "$CMD" "$THIS_SCRIPT_DIR/NonAscii/expected-ouput-only-ascii.txt"

popd >/dev/null


echo "All tests finished."
