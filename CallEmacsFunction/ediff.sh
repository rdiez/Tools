#!/bin/bash

# This script uses call-emacs-function.sh in order to run Ediff on a pair of files.
#
# It needs a routine like the following in your Emacs configuration:
#
#   (defun my-ediff-files-from-outside (filename-a filename-b)
#     "" ; No docstring yet.
#     (ediff-files filename-a filename-b))
#
# You could call ediff-files directly, but I needed to customize the code in my Emacs configuration.
#
# Copyright (c) 2026 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
# Script version 1.00

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


# ------ Entry Point (only by convention) ------

if (( $# != 2 )); then
  abort "Invalid command-line arguments. Please specify both filenames to compare."
fi

declare -r CALL_EMACS_FUNCTION_FILENAME="call-emacs-function.sh"

if ! is_tool_installed "$CALL_EMACS_FUNCTION_FILENAME"; then
  abort "Helper script \"$CALL_EMACS_FUNCTION_FILENAME\" not found."
fi

declare -r FILENAME_1="$1"
declare -r FILENAME_2="$2"

if ! [ -f "$FILENAME_1" ]; then
  abort "File \"$FILENAME_1\" does not exist or is not a regular file."
fi

if ! [ -f "$FILENAME_2" ]; then
  abort "File \"$FILENAME_2\" does not exist or is not a regular file."
fi

exec "$CALL_EMACS_FUNCTION_FILENAME" --suppress-output -- "my-ediff-files-from-outside" "$FILENAME_1" "$FILENAME_2"
