#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME="print-arguments-wrapper.sh"
VERSION_NUMBER="2.01"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2014 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "When writing complex shell scripts, sometimes you wonder if a particular process is getting the right arguments and the right environment variables. Just prefix a command with the name of this script, and it will dump all arguments and environment variables to the console before starting the child process."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> command <command arguments...>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Usage examples"
  echo "  ./$SCRIPT_NAME echo \"test\""
  echo
  echo "Caveat: Some shell magic may be lost in the way. Consider the following example:"
  echo "   ./$SCRIPT_NAME ls -la"
  echo "Command 'ls' may be actually be an internal shell function or an alias to 'ls --color=auto', but that will not be taken into consideration any more when using this wrapper script. For example, the external /bin/echo tool will be executed instead of the shell built-in version."
  echo
  echo "Exit status: Same as the command executed."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2011-2014 R. Diez

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

if [ $# -lt 1 ]; then
  echo
  echo "You need to specify at least an argument. Run this tool with the --help option for usage information."
  echo
  exit 1
fi

case "$1" in
  --help)
    display_help
    exit 0;;
  --license)
    display_license
    exit 0;;
  --version)
    echo "$VERSION_NUMBER"
    exit 0;;
  --*) abort "Unknown option \"$1\".";;
esac


ACTUAL_SCRIPT_NAME="$0"

echo
echo "Wrapper script \"$ACTUAL_SCRIPT_NAME\" is about to run process \"$1\" with the following environment variables:"
echo
export
echo

echo "Wrapper script \"$ACTUAL_SCRIPT_NAME\" is about to run the following process with $(($# - 1)) argument(s):"
echo

echo "- Process name: $1"

PRINT_CMD="$(printf "%q" "$1")"

if [ $# -gt 1 ]; then

  declare -a ARGUMENTS=("$@")
  unset 'ARGUMENTS[0]'  # Remove the first element.

  declare -i COUNTER=1

  for arg in "${ARGUMENTS[@]}"
  do
    printf "%s Argument  %02d: %s\\n" "-" "$COUNTER" "$arg"
    COUNTER=$COUNTER+1
    PRINT_CMD+=" $(printf "%q" "$arg")"
  done

fi

echo

echo "The properly shell-quoted command line is:"
echo
echo "$PRINT_CMD"
echo
echo "Wrapper script \"$ACTUAL_SCRIPT_NAME\" will run process \"$1\" now:"
echo

exec -- "$@"
