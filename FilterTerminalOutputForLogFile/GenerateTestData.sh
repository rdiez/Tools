#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


declare -r LINE_TEXT="<---------------------------------------------------------------------------------------------------------------------------------------->"


# ------- Entry point -------

if (( $# != 2 )); then
  abort "Invalid number of command-line arguments."
fi

declare -r -i NORMAL_LINE_COUNT="$1"
declare -r -i PROGRESS_LINE_COUNT="$2"

echo "First line."

declare -i NORMAL_LINE_INDEX
declare -i PROGRESS_LINE_INDEX

for (( NORMAL_LINE_INDEX = 1; NORMAL_LINE_INDEX <= NORMAL_LINE_COUNT; NORMAL_LINE_INDEX++ )); do
  printf "Normal line %d - %s\\n"  "$NORMAL_LINE_INDEX" "$LINE_TEXT"
done


for (( PROGRESS_LINE_INDEX = 1; PROGRESS_LINE_INDEX <= PROGRESS_LINE_COUNT; PROGRESS_LINE_INDEX++ )); do
  printf "Progress line %d - %s\\r"  "$PROGRESS_LINE_INDEX" "$LINE_TEXT"
done

printf "\\n"

echo "Last line."

echo "Finished."
