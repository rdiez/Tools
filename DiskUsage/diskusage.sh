#!/bin/bash

# Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit "$EXIT_CODE_ERROR"
}


if (( $# == 0 )); then

  abort "Missing arguments."

fi

printf  -v QUOTED_PARAMS " %q"  "$@"

# 'sort' options:
# hr = --human-numeric-sort and --reverse
# f = --ignore-case

CMD="du  --bytes  --human-readable  --summarize  --si  $QUOTED_PARAMS  |  sort  --key=1hr,2f"

echo "$CMD"
echo
eval "$CMD"
