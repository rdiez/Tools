#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="xsudo.sh"
declare -r VERSION_NUMBER="1.01"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2018-2019 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This is a simple wrapper for pkexec as a substitute for gksudo."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME command <command arguments...>"
  echo
  echo "Exit status: Either the exit status from pkexec, or some non-zero value on failure."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2018 R. Diez

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


# ----------- Entry point -----------

if (( $# < 1 )); then
  echo
  echo "You need to specify at least one argument. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
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

  --*) abort "Unknown option \"$1\".";;

esac

if [ $# -eq 0 ]; then
  echo
  echo "No command specified. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
fi


printf -v ARGS " %q"  "$@"

if ! is_var_set DISPLAY; then
  abort "Environment variable DISPLAY must be set."
fi

printf -v CMD  "pkexec  env  DISPLAY=%q"  "$DISPLAY"

# If you are starting your own VNC server, environment variable XAUTHORITY may not be set.
if is_var_set XAUTHORITY; then
  printf -v TMP  "XAUTHORITY=%q"  "$XAUTHORITY"
  CMD+="  $TMP"
fi

# Unfortunately, tool 'env' does not seem to support '--' as a separator between its options
# and the command to run, at least in coreutils version 8.25.
CMD+="  $ARGS"

echo "$CMD"
eval "$CMD"
