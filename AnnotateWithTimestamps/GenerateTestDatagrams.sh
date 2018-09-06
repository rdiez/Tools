#!/bin/bash
#
# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


if (( $# != 0 )); then
  abort "Invalid number of command-line arguments. This script takes no arguments. The output goes to stdout."
fi


declare -ri REPEAT_COUNT=5

for (( repeat = 0; repeat < REPEAT_COUNT; ++repeat )); do

  DATA=""
  DATA+="A"
  DATA+="bcdefg"
  DATA+="Z"

  printf "%s" "$DATA"

  sleep 0.2

done
