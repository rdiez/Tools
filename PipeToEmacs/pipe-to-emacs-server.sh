#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="2.04"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


declare -r EMACS_BASE_PATH_ENV_VAR_NAME="EMACS_BASE_PATH"


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2021 R. Diez - Licensed under the GNU AGPLv3"
  echo "Based on a similar utility by Phil Jackson (phil@shellarchive.co.uk)"
  echo
  echo "This tool helps you pipe the output of a shell console command to a new Emacs window."
  echo
  echo "The Emacs instance receiving the text must already be running in the local PC, and must have started the Emacs server, as this script uses the 'emacsclient' tool. See Emacs' function 'server-start' for details. I tried to implement this script so that it would start Emacs automatically if not already there, but I could not find a clean solution. See this script's source code for more information. The reason why the Emacs server must be running locally is that the generated lisp code needs to open a local temporary file where the piped text is stored."
  echo
  echo "If you Emacs is not on the PATH, se environment variable $EMACS_BASE_PATH_ENV_VAR_NAME."
  echo
  echo "If you are running on Cygwin and want to use the native Windows Emacs (the Win32 version instead of the Cygwin one), set environment variable PIPETOEMACS_WIN32_PATH to point to your Emacs binaries. For example:"
  echo "  export PIPETOEMACS_WIN32_PATH=\"c:/emacs-24.3\""
  echo
  echo "Usage examples:"
  echo "  ls -la | $SCRIPT_NAME"
  echo "  my-program 2>&1 | $SCRIPT_NAME  # Include output to stderr too."
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

Copyright (c) 2011-2021 R. Diez

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
    --*) abort "Unknown option \"$1\".";;
    *) abort "This tool takes no arguments. Run this tool with the --help option for usage information.";;
  esac
fi


# If the user starts the tool from a terminal without piping any input...
if [ -t 0 ]
then
  abort "This tool is designed to take text data from stdin, by using a pipe to forward data from another process. Run this tool with the --help option for usage information."
fi

TMP_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.txt")"

# If variable PIPETOEMACS_WIN32_PATH is set...
if [ "${PIPETOEMACS_WIN32_PATH:=""}" != "" ]; then
  TMP_FILENAME_FOR_EMACS_LISP="$(cygpath --mixed -- "$TMP_FILENAME")"
  EMACSCLIENT="$PIPETOEMACS_WIN32_PATH/bin/emacsclient"
else
  TMP_FILENAME_FOR_EMACS_LISP="$TMP_FILENAME"

  if is_var_set "$EMACS_BASE_PATH_ENV_VAR_NAME"; then
    declare -r EMACSCLIENT="${!EMACS_BASE_PATH_ENV_VAR_NAME}/bin/emacsclient"
  else
    declare -r EMACSCLIENT="emacsclient"
  fi
fi

cat - > "$TMP_FILENAME"

LISP_CODE="(progn "

# Emacs function 'switch-to-buffer' replaces the current window (pane) with the piped contents.
# There is advice on the Internet about using 'pop-to-buffer-same-window' for
# this purpose instead,  but I did not understand the reason why.
#
# In any case, I find that behaviour annoying, because I usually run this script from within a shell window
# inside Emacs, and I would like to keep that shell visible. This is why I have switched
# to using 'pop-to-buffer'.
declare -r WINDOW_FUNCTION="pop-to-buffer"

LISP_CODE+="($WINDOW_FUNCTION (generate-new-buffer \"*stdin*\"))"

# As of january 2014, the Cygwin console seems to using UTF-8. If you pipe text to Emacs, international characters
# will probably not work. Forcing UTF-8 here seems to do the trick. On Linux, everything should be UTF-8 anyway.
LISP_CODE+="(let ((coding-system-for-read 'utf-8))"

LISP_CODE+="(insert-file \"$TMP_FILENAME_FOR_EMACS_LISP\")"

LISP_CODE+=")"

LISP_CODE+="(end-of-buffer)"
# This does not seem necessary:
#   LISP_CODE+="(select-frame-set-input-focus (window-frame (selected-window)))"
LISP_CODE+=")"

# About why an Emacs server instance must already be running:
#
# The 'emacsclient' tool has an '--alternate-editor' argument that can start a new Emacs instance
# if an existing one is not reachable over the server socket. The trouble is, as of version 24.3,
# the new Emacs instance is not started with the --eval argument, so this script breaks.
#
# On this web page I found the following workaround:
#   http://www.emacswiki.org/emacs/EmacsClient
# If you start emacsclient with argument '--alternate-editor="/usr/bin/false"', it will fail,
# and then you can start Emacs with the --eval argument. Caveats are:
# - emacsclient prints ugly error messages.
# - emacsclient does not document that its exit code will indicate a failure if --alternate-editor fails.
# - There is no way to tell whether something else failed.
# - Starting "emacs --eval" is problematic. This script would then wait forever for the new Emacs instance to terminate.
#   If Emacs were to be started in the background, there is no way to find out if it failed.
# After considering all the options, I decide to keep this script clean and simple, at the cost
# of demanding an existing Emacs server. For serious Emacs users, that is the most common scenario anyway.

set +o errexit

"$EMACSCLIENT" -e "$LISP_CODE" >/dev/null

declare -r -i EMACS_CLIENT_EXIT_CODE="$?"

set -o errexit

# Alternative: Let Emacs delete the file with (delete-file "filename"). But beware that we would need
#              to delete it here anyway if emacsclient fails.
rm -- "$TMP_FILENAME"

if (( EMACS_CLIENT_EXIT_CODE != 0 )); then
  # abort "emacsclient failed with exit code $EMACS_CLIENT_EXIT_CODE."
  exit $EMACS_CLIENT_EXIT_CODE
fi
