#!/bin/bash

# Script version 2.01.
#
# This script reads a template text file and replaces all occurrences
# of the given placeholder string with the contents of another file.
# The resulting text is printed to stdout.
#
# Usage example:
#  ./ReplaceTemplatePlaceholderWithFileContents.sh  template.txt  PLACEHOLDER  replacement.txt
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


# WARNING: Option extglob should be disabled before using the escaped pattern returned by
#          this routine. Otherwise, there are more characters to escape.

escape_bash_pattern ()
{
  ESCAPED_BASH_PATTERN="$1"

  # Character '\' -> '\\'.
  ESCAPED_BASH_PATTERN="${ESCAPED_BASH_PATTERN//\\/\\\\}"

  # Character '*' -> '\*'.
  ESCAPED_BASH_PATTERN="${ESCAPED_BASH_PATTERN//\*/\\*}"

  # Character '?' -> '\?'.
  ESCAPED_BASH_PATTERN="${ESCAPED_BASH_PATTERN//\?/\\?}"

  # Character '[' -> '\['.
  ESCAPED_BASH_PATTERN="${ESCAPED_BASH_PATTERN//\[/\\[}"

  # Character ']' -> '\]'.
  ESCAPED_BASH_PATTERN="${ESCAPED_BASH_PATTERN//\]/\\]}"
}


if [ $# -ne 3 ]; then
  abort "Wrong number of command-line arguments. See this script's source code for more information."
fi

TEMPLATE_FILENAME="$1"
PLACEHOLDER_STRING="$2"
REPLACEMENT_FILENAME="$3"


# I have not found a way yet to make Bash keep the end-of-line characters at the end
# of the file when using the $(<filename.txt) syntax.
# Later note: This is probably feasible with mapfile/readarray like this: readarray VAR_NAME < filename.txt
TEMPLATE_CONTENTS="$(cat "$TEMPLATE_FILENAME" && printf "keep-end-of-lines-at-the-end")"
TEMPLATE_CONTENTS="${TEMPLATE_CONTENTS%keep-end-of-lines-at-the-end}"

REPLACEMENT_STRING="$(cat "$REPLACEMENT_FILENAME" && printf "keep-end-of-lines-at-the-end")"
REPLACEMENT_STRING="${REPLACEMENT_STRING%keep-end-of-lines-at-the-end}"

# Disable extglob, which means there are less special characters to escape
# when bash does pattern matching. Otherwise, you need to
# amend escape_bash_pattern().
shopt -u extglob

escape_bash_pattern "$PLACEHOLDER_STRING"

PLACEHOLDER_STRING_ESCAPED="$ESCAPED_BASH_PATTERN"

# Bash does not expand the replacement string. Therefore, REPLACEMENT_STRING does not need to be escaped.

printf "%s" "${TEMPLATE_CONTENTS//$PLACEHOLDER_STRING_ESCAPED/$REPLACEMENT_STRING}"
