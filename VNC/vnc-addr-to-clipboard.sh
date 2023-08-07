#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace this script.

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


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
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


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2023 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This script finds out this computer's public IP address using public service \"$PUBLIC_SERVICE_NAME\""
  echo "and places in the clipboard a connection address that your partner can use"
  echo "in order to start a reverse VNC connection to this computer."
  echo
  echo "If you have set up a 55xx VNC port forward on the Internet router, define an environment"
  echo "variable named $PORT_FORWARD_ENV_VAR_NAME with the public TCP port,"
  echo "and this script will add an adequate VNC-style suffix to the IP address."
  echo
  echo "This script is just for convenience, as you can always manually find out"
  echo "your public IP address and build such a reverse VNC connection string yourself."
  echo
  echo "In order to use this script, just run it, and afterwards, paste the copied text"
  echo "from the X clipboard into any application."
  echo
  echo "You can also specify one of the following options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Exit status: $EXIT_CODE_SUCCESS means success, anything else is an error."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2023 R. Diez

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


# ------- Entry point (sort of) -------

declare -r XSEL_TOOLNAME="xsel"
declare -r CURL_TOOLNAME="curl"

# There are other providers and other methods to get your public IP address,
# but this script only implements this one at the moment:
declare -r PUBLIC_SERVICE_NAME="ifconfig.co"

declare -r PORT_FORWARD_ENV_VAR_NAME="VNC_TCP_PORT_FORWARD_PUBLIC"

declare -r ERR_MSG_HELP_OPTION="Run this tool with the --help option for usage information."

if (( $# == 1 )); then

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
    # --) shift;;   We do not need this, because we have no other command-line arguments.
    -*) abort "Unknown option \"$1\". $ERR_MSG_HELP_OPTION";;
  esac

fi

if (( $# != 0 )); then
  abort "Invalid command-line arguments. $ERR_MSG_HELP_OPTION"
fi


verify_tool_is_installed "$CURL_TOOLNAME" "curl"

verify_tool_is_installed "$XSEL_TOOLNAME" "xsel"


echo "Requesting the public IP address..."

# Command 'declare' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
declare PUBLIC_IP

PUBLIC_IP="$(curl --silent --show-error -4 --url "$PUBLIC_SERVICE_NAME")"


VNC_CNX_STR="$PUBLIC_IP"

if is_var_set "$PORT_FORWARD_ENV_VAR_NAME"; then

  PORT_FORWARD_VALUE="${!PORT_FORWARD_ENV_VAR_NAME}"

  # Listening VNC connections use port 5500 by default, but you can use ports 5501, 5502, etc.
  # by specifying the "1", "2", etc. number as a suffix.

  declare -r PORT_FORWARD_REGEX="^55([0-9][0-9])\$"

  if ! [[ $PORT_FORWARD_VALUE =~ $PORT_FORWARD_REGEX ]]; then
    abort "Environment variable $PORT_FORWARD_ENV_VAR_NAME has value \"$PORT_FORWARD_VALUE\", which is not a 55xx number."
  fi

  VNC_PORT_NUMBER="${BASH_REMATCH[1]}"

  printf  -v VNC_PORT_NUMBER_NO_LEADING_ZERO  "%d"  "$VNC_PORT_NUMBER"

  VNC_CNX_STR+=":$VNC_PORT_NUMBER_NO_LEADING_ZERO"

fi


# Note that xsel forks and detaches from the terminal (if it is not just clearing the clipboard).
# xsel then waits indefinitely for other programs to retrieve the text it is holding,
# perhaps multiple times. When something else replaces or deletes the clipboard's contents,
# xsel automatically terminates.

echo -n "$VNC_CNX_STR" | "$XSEL_TOOLNAME" --input --clipboard


echo "Reverse VNC connection address copied to the clipboard: $VNC_CNX_STR"
