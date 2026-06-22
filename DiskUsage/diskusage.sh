#!/bin/bash

# Copyright (c) 2022-2026 R. Diez - Licensed under the GNU AGPLv3
#
# Script version 1.01.

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit "$EXIT_CODE_ERROR"
}


if (( $# == 0 )); then

  abort "Missing arguments."

fi

printf  -v QUOTED_PARAMS " %q"  "$@"

# 'sort' options (use '--debug' to troubleshoot):
# b = ignore leading blanks, otherwise blanks (even separators) are included in the sorting
# hr = --human-numeric-sort and --reverse
# f = --ignore-case

declare -r CMD="du  --bytes  --human-readable  --summarize  --si  $QUOTED_PARAMS  |  sort  --key=1bhr,1  --key=2bf,2"

echo "$CMD"
echo
eval "$CMD"
