#!/bin/bash

# This script adds extra content in the background (typically a letterhead or watermark)
# to all pages of a PDF document.
#
# The extra content comes from a second PDF file. The path to that second PDF file is hard-coded
# in this script.
#
# The original PDF document is replaced (it is changed in-place). This script checks beforehand
# whether the PDF already has the extra background content.
#
# You need the pdftk tool installed on your system. On Ubuntu/Debian, the package is called 'pdftk'.
#
# Copyright (c) 2016 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="add-letterhead.sh"

# Specify here your own PDF file with the background contents.
declare -r LETTERHEAD_FILENAME="/full/path/to/letterhead.pdf"

# Specify here the magic string to be found inside your letterhead PDF file.
# In order to find a good magic string, use a text editor like emacs,
# search for a suitable data stream, and take the first bytes.
# For example, such a magic stream could look like this:
#   MAGIC_STRING_IN_LETTERHEAD=$'abc\101\102\103def'
# This script checks for the magic string in all 3 files: original document,
# letterhead, and resulting document. Therefore, it should be pretty difficult
# to make a mistake with the magic string.
declare -r MAGIC_STRING_IN_LETTERHEAD=$'abc\101\102\103def'


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi

PDF_FILENAME="$1"


FILE_EXTENSION="${PDF_FILENAME##*.}"
FILE_EXTENSION_UPPERCASE=${FILE_EXTENSION^^}

if [[ $FILE_EXTENSION_UPPERCASE != PDF ]]; then
  abort "This script operates only on .pdf files"
fi


set +o errexit
grep  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$LETTERHEAD_FILENAME"
GREP_EXIT_CODE="$?"
set -o errexit

case "$GREP_EXIT_CODE" in
  0) ;;  # Nothing to do here.
  1) abort "The letterhead file does not contain the magic string.";;
  2) exit "$GREP_EXIT_CODE";;  # grep has printed an error message already.
  *) abort "Unexpected exit code $GREP_EXIT_CODE from grep.";;
esac


set +o errexit
grep  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$PDF_FILENAME"
GREP_EXIT_CODE="$?"
set -o errexit

case "$GREP_EXIT_CODE" in
  0) abort "The given file already has the letterhead.";;
  1) ;;  # Nothing to do here.
  2) exit "$GREP_EXIT_CODE";;  # grep has printed an error message already.
  *) abort "Unexpected exit code $GREP_EXIT_CODE from grep.";;
esac

TMP_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.pdf")"
# echo "TMP_FILENAME: $TMP_FILENAME"

# Try to delete the temporary file on exit. It is no hard guarantee,
# but it usually works. Hopefully, the operating system
# will clean the temporary directory every now and then.

printf -v TMP_FILENAME_QUOTED "%q" "$TMP_FILENAME"
trap "rm -f -- $TMP_FILENAME_QUOTED" EXIT


pdftk  "$PDF_FILENAME"  background "$LETTERHEAD_FILENAME"  output "$TMP_FILENAME"

set +o errexit
grep  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$TMP_FILENAME"
GREP_EXIT_CODE="$?"
set -o errexit

case "$GREP_EXIT_CODE" in
  0) ;;  # Nothing to do here.
  1) abort "The generated PDF file does not contain the letterhead magic string.";;
  2) exit "$GREP_EXIT_CODE";;  # grep has printed an error message already.
  *) abort "Unexpected exit code $GREP_EXIT_CODE from grep.";;
esac

# We could use here 'mv' instead, but then we should really cancel the "trap EXIT" above.
cp -- "$TMP_FILENAME"  "$PDF_FILENAME"
