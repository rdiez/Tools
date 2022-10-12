#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.00"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


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


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  if is_tool_installed "$TOOL_NAME"; then
    return
  fi

  local ERR_MSG="Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager."

  if [[ $DEBIAN_PACKAGE_NAME != "" ]]; then
    ERR_MSG+=" For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
  fi

  abort "$ERR_MSG"
}

declare -r XSEL_TOOLNAME="xsel"


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This script places the absolute path of the given filename in the X clipboard."
  echo "The specified file or directory must exist."
  echo
  echo "This tool is just a wrapper around '$XSEL_TOOLNAME', partly because I can never remember its command-line arguments."
  echo
  echo "Usage example:"
  echo "  $SCRIPT_NAME -- some/file/or/dir"
  echo "Afterwards, paste the copied text from the X clipboard into any application."
  echo
  echo "You can also specify one of the following options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Exit status: 0 means success, anything else is an error."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2022 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


declare -r ERR_MSG_INVALID_ARGS="Invalid command-line arguments. Run this tool with the --help option for usage information."

if (( $# == 0 )); then
  abort "$ERR_MSG_INVALID_ARGS"
fi

case "$1" in
  --help)
    display_help
    exit $EXIT_CODE_SUCCESS;;
  --license)
    display_license
    exit $EXIT_CODE_SUCCESS;;
  --version)
    echo "$VERSION_NUMBER"
    exit $EXIT_CODE_SUCCESS;;
  --) shift;;
  -*) abort "Unknown option \"$1\".";;
esac

if (( $# != 1 )); then
  abort "$ERR_MSG_INVALID_ARGS"
fi

declare -r FILENAME="$1"

ABS_FILENAME="$(readlink --canonicalize-existing --verbose -- "$FILENAME")"

if [[ "$ABS_FILENAME" != "/" && -d "$ABS_FILENAME" ]]; then
  ABS_FILENAME+="/"
fi

verify_tool_is_installed "$XSEL_TOOLNAME" "xsel"

echo -n "$ABS_FILENAME" | "$XSEL_TOOLNAME" --input --clipboard

# Note that xsel forks and detaches from the terminal (if it is not just clearing the clipboard).
# xsel then waits indefinitely for other programs to retrieve the text it is holding,
# perhaps multiple times. When something else replaces or deletes the clipboard's contents,
# xsel automatically terminates.

echo "Path copied to the clipboard: $ABS_FILENAME"
