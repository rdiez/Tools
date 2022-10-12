#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="2.01"

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
  echo "This script helps you pipe the output of a shell command to the X clipboard."
  echo
  echo "It is just a wrapper around '$XSEL_TOOLNAME', partly because I can never remember its command-line arguments."
  echo
  echo "In case of a single text line, the script automatically removes the end-of-line character."
  echo "Otherwise, pasting the text to a shell console becomes annoying."
  echo
  echo "Usage example:"
  echo "  echo \"whatever\" | $SCRIPT_NAME"
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


if (( $# != 0 )); then
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
    -*) abort "Unknown option \"$1\".";;
    *) abort "This tool takes no arguments. Run this tool with the --help option for usage information.";;
  esac
fi


# If the user starts the tool from a terminal without piping any input...
if [ -t 0 ]; then
  MSG="This tool is designed to take text data from stdin, by using a pipe to forward data from another process."
  MSG+=" Run this tool with the --help option for usage information."
  abort "$MSG"
fi

# Alternatively, you could use tool 'xclip' as follows, but the following xclip command does not work well with Emacs.
# I don't know why, but I suspect it's because xclip remains as a background process detached from the console
# and it does not close stdout.
#   exec xclip -i -selection clipboard

verify_tool_is_installed "$XSEL_TOOLNAME" "xsel"


if false; then

  # The output of a shell command is often a single word or a single line of text,
  # followed by an end-of-line character. That end-of-line character becomes annoying
  # if you paste the text to a shell console. That is the reason why I decided
  # to remove the end-of-line character if there is just one line of text.
  #
  # I kept this implementation for future reference, in case I do not want
  # to modify the data anymore.

  exec "$XSEL_TOOLNAME" --input --clipboard

else

  readarray TEXT_LINES

  declare -r -i TEXT_LINE_COUNT="${#TEXT_LINES[@]}"

  if false; then
    echo "TEXT_LINE_COUNT=$TEXT_LINE_COUNT"
    for (( i=0; i < TEXT_LINE_COUNT; i++ )); do
      echo "$(( i + 1 )): <${TEXT_LINES[ $i ]}>"
    done
  fi

  if (( TEXT_LINE_COUNT == 0 )); then

    # This is the case with a command like this:
    #   echo -n "" | pipe-to-clipboard.sh

    # We could also supply an empty string to 'xsel',
    # which seems to have the same effect as clearing the clipboard.

    "$XSEL_TOOLNAME" --clear --clipboard

    echo "Got no text, clipboard cleared."

  elif (( TEXT_LINE_COUNT == 1 )); then

    FIRST_TEXT_LINE="${TEXT_LINES[0]}"

    # The text line can be just one character, or just one end-of-line character,
    # but it cannot be completely empty.
    if [ -z "$FIRST_TEXT_LINE" ]; then
      abort "Internal error: The text line is not expected to be empty."
    fi

    # Remove an eventual end-of-line character.
    FIRST_TEXT_LINE="${FIRST_TEXT_LINE%$'\n'}"

    if [ -z "$FIRST_TEXT_LINE" ]; then

      # This is the case with a command like this:
      #   echo "" | pipe-to-clipboard.sh
      # The new-line character makes it 1 text line.

      # We don't actually need this special case, because supplying an empty string
      # to 'xsel' seems to have the same effect as clearing the clipboard.

      "$XSEL_TOOLNAME" --clear --clipboard

      echo "Got an empty text line, clipboard cleared."

    else

      echo -n "$FIRST_TEXT_LINE" | "$XSEL_TOOLNAME" --input --clipboard

      echo "1 text string placed on the clipboard."

    fi

  else

    {
      for (( i = 0; i < TEXT_LINE_COUNT; i++ )); do
        echo -n "${TEXT_LINES[ $i ]}"
      done
    } | "$XSEL_TOOLNAME" --input --clipboard

    echo "$TEXT_LINE_COUNT text lines placed on the clipboard."

  fi

fi

# Note that xsel forks and detaches from the terminal (if it is not just clearing the clipboard).
# xsel then waits indefinitely for other programs to retrieve the text it is holding,
# perhaps multiple times. When something else replaces or deletes the clipboard's contents,
# xsel automatically terminates.
