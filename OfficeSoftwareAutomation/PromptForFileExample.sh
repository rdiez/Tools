#!/bin/bash

# This script is an example on how to call PromptForFile.vbs from Cygwin.
#
# Care is taken that filenames with international (Unicode) characters work too.
#
# These are the test cases that I have used when developing this script:
# - Compilation error in .vbs script.
# - The .vbs script writes a "normal" error.
# - The file chooser prompt is cancelled.
# - The mintty console is not configured for UTF-8 (and also export LANG="de_DE.UTF-8"),
#   but for codepage 1252 (and also export LANG=de_DE.CP1252).
#
# Script version 1.02.
#
# Copyright (c) 2016 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="PromptForFileExample.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


prompt_for_filename ()
{
  local TEMPORARY_FILENAME_COMPONENT="$1"
  local PROMPT_TEXT="$2"
  local INITIAL_DIRNAME_WINDOWS="$3"
  local FILE_TYPE_DESCRIPTION="$4"
  local FILE_EXTENSION="$5"

  # Cygwin's mintty console usually works in UTF-8 mode, but it can be configured with a Windows codepage.
  # The Cygwin environment can also have a different encoding or codepage set, see
  # the LANG and LC_ALL environment variables. The only way I found to reliably capture
  # international characters is to run cscript with switch //U while redirecting to a file.
  # cscript's documentation does mention that, when redirecting stdout to a file with //U,
  # the generated text is in Unicode (UCS-2) format. The .vbs script has to be careful to always
  # write to the console with WScript.Echo for option //U to have an effect.

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command inkoved.
  local TMP_FILENAME
  TMP_FILENAME="$(mktemp --tmpdir -- "tmp.$TEMPORARY_FILENAME_COMPONENT.XXXXXXXXXX.txt")"

  if false; then
    echo "TMP_FILENAME: $TMP_FILENAME"
  fi

  local -r VBS_SCRIPT_FILENAME_WINDOWS="PromptForFile.vbs"


  # If cscript finds a compilation error, the corresponding error message is normally lost if started within
  # a Cygwin mintty console. However, if we redirect stdout to stderr beforehand,
  # we can always capture such error messages.
  # Other errors are apparently not output to stderr, but to stdout. Our .vbs script writes error messages
  # to stdout on purpose, see the comment above about capturing international characters.
  # Therefore, if something goes wrong, we need to print a generic error message, and then we also need
  # to print any captured text too.

  set +o errexit

  cscript //NoLogo //U "$VBS_SCRIPT_FILENAME_WINDOWS" "$PROMPT_TEXT" "$INITIAL_DIRNAME_WINDOWS" "$FILE_TYPE_DESCRIPTION" "$FILE_EXTENSION" >"$TMP_FILENAME" 2>&1
  local CSCRIPT_EXIT_CODE="$?"

  # Run iconv without automatic error checking in case the temporary file could not be created or cannot be read or converted.
  # Command 'local' is in a separate line, in order to prevent masking any error from the external command inkoved.
  local CSCRIPT_OUTPUT
  CSCRIPT_OUTPUT="$(iconv --from-code=UCS-2LE -- "$TMP_FILENAME")"
  local ICONV_EXIT_CODE="$?"

  set -o errexit

  rm -f -- "$TMP_FILENAME"


  # Remove all of Windows 0x0D (Carriage Return) characters from the captured text. The removal of the last one
  # is especially important, in case the capture text is the filename that we will be returning.
  CSCRIPT_OUTPUT=${CSCRIPT_OUTPUT//$'\r'/}


  if [ $CSCRIPT_EXIT_CODE -ne 0 ]; then
    # If iconv could read and convert any error messages, output them here first.
    echo "$CSCRIPT_OUTPUT"
    echo "Script $VBS_SCRIPT_FILENAME_WINDOWS failed." >&2
    return $CSCRIPT_EXIT_CODE
  fi

  if [ $ICONV_EXIT_CODE -ne 0 ]; then
    echo "iconv failed." >&2
    return $ICONV_EXIT_CODE
  fi


  FILENAME_WINDOWS="$CSCRIPT_OUTPUT"

  if [[ $FILENAME_WINDOWS = "" ]]; then
    FILENAME=""
  else
    FILENAME="$(cygpath --unix -- "$FILENAME_WINDOWS")"
  fi
}


if [ $# -ne 0 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi


# INITIAL_DIRNAME_WINDOWS="C:\\Windows"
INITIAL_DIRNAME_WINDOWS="$(cygpath --windows -- "$PWD")"

prompt_for_filename  "$SCRIPT_NAME"  "Please choose a text file"  "$INITIAL_DIRNAME_WINDOWS"  "Text files"  "txt"

if [[ $FILENAME = "" ]]; then
  echo "The user cancelled the filename dialog prompt."
  exit 0
fi

echo "Captured filename Windows: $FILENAME_WINDOWS"
echo "Captured filename Cygwin : $FILENAME"

echo "Directory listing of just that file:"
ls -la -- "$FILENAME"
