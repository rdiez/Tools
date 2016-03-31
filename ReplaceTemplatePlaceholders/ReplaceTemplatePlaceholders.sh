#!/bin/bash

# Script version 2.00.
#
# This script reads a template text file and replaces all occurrences
# of the given placeholder strings with the given strings.
# The resulting text is printed to stdout.
#
# Usage:
#  ./ReplaceTemplatePlaceholders.sh  template.txt  placeholder1 replacement1  [placeholder2 replacement2 [...] ]
#
#   Note that, for each substitution, there is always a pair of command-line arguments:
#   the placeholder string and its replacement string.
#
# Usage examples:
#
#  ./ReplaceTemplatePlaceholders.sh  template.txt  "placeholder1" "replacement1"
#  ./ReplaceTemplatePlaceholders.sh  form.txt  "[NAME]" "foo"  "[ADDRESS]" "bar"
#  ./ReplaceTemplatePlaceholders.sh  spreadsheet.txt  "CURRENCY" "\$"
#  ./ReplaceTemplatePlaceholders.sh  unix2dos.txt  $'\n' $'\r\n'
#
# This script properly escapes the strings internally, so any character sequence should work,
# except for the null character (0), which is a limitation imposed by Bash. I have tested
# new-line characters in both placeholder names and replacement strings, and even that works fine.
# If you find a character escaping bug, please drop me a line.
#
#  Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


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


# --------- Entry point ---------

if [ $# -lt 3 ]; then
  abort "Wrong number of command-line arguments."
fi

TEMPLATE_FILENAME="$1"
shift

# I have not found a way yet to make Bash keep the end-of-line characters at the end
# of the file when using the $(<filename.txt) syntax.
TEMPLATE_CONTENTS="$(cat "$TEMPLATE_FILENAME" && printf "keep-end-of-lines-at-the-end")"
TEMPLATE_CONTENTS="${TEMPLATE_CONTENTS%keep-end-of-lines-at-the-end}"


if (( ( $# % 2 ) != 0 )); then
  abort "Wrong number of command-line arguments."
fi


# Disable extglob, which means there are less special characters to escape
# when bash does pattern matching. Otherwise, you need to
# amend escape_bash_pattern().
shopt -u extglob


while (( $# > 0 ))
do

  PLACEHOLDER_STRING="$1"
  REPLACEMENT_STRING="$2"
  shift 2

  escape_bash_pattern "$PLACEHOLDER_STRING"

  PLACEHOLDER_STRING_ESCAPED="$ESCAPED_BASH_PATTERN"

  if false; then
    echo "$PLACEHOLDER_STRING -> $REPLACEMENT_STRING"
    echo "PLACEHOLDER_STRING_ESCAPED: $PLACEHOLDER_STRING_ESCAPED"
  fi

  TEMPLATE_CONTENTS="${TEMPLATE_CONTENTS//$PLACEHOLDER_STRING_ESCAPED/$REPLACEMENT_STRING}"

done

printf "%s" "$TEMPLATE_CONTENTS"
