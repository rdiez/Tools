#!/bin/bash

# This script reads a template text file and replaces all occurrences
# of the given placeholder string with the contents of another file.
# The resulting text is printed to stdout.
#
# Usage example:
#  ReplaceTemplatePlaceholderWithFileContents.sh  template.txt  PLACEHOLDER  replacement.txt
#
#  Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if [ $# -ne 3 ]; then
  abort "Wrong number of command-line arguments. See this script's source code for more information."
fi

TEMPLATE_FILENAME="$1"
PLACEHOLDER_STRING="$2"
REPLACEMENT_FILENAME="$3"

TEMPLATE_CONTENTS="$(<"$TEMPLATE_FILENAME")"

REPLACEMENT_STRING="$(<"$REPLACEMENT_FILENAME")"

echo "${TEMPLATE_CONTENTS//$PLACEHOLDER_STRING/$REPLACEMENT_STRING}"
