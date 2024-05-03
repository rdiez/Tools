#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace this script.

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.02"

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

declare -r -i DEFAULT_REVERSE_VNC_PORT=5500


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2024 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This script finds out this computer's global IPv6 address (without any external service)"
  echo "and places in the clipboard a connection string which your partner can use"
  echo "in order to start a reverse VNC connection to this computer."
  echo
  echo "If you are not using the default TCP port $DEFAULT_REVERSE_VNC_PORT, define an environment variable"
  echo "named $PORT_FORWARD_ENV_VAR_NAME with the TCP port, and this script"
  echo "will use the specified port number instead of the default one."
  echo "This could pose problems on some VNC servers due to ambiguity between TCP port and 'display' number,"
  echo "like \"hostname:display\" and \"hostname::port\". Recent TightVNC server versions will probably work well."
  echo "See the comments in the source code for details about this ambiguity."
  echo
  echo "This script is just for convenience, as you can always manually find out"
  echo "your global IPv6 address and build such a reverse VNC connection string yourself."
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

Copyright (c) 2024 R. Diez

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


# ------- Entry Point (only by convention) -------

declare -r XSEL_TOOLNAME="xsel"
declare -r JQ_TOOLNAME="jq"

declare -r PORT_FORWARD_ENV_VAR_NAME="VNC_IPV6_TCP_PORT_FORWARD_PUBLIC"

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


verify_tool_is_installed "$JQ_TOOLNAME" "jq"

verify_tool_is_installed "$XSEL_TOOLNAME" "xsel"


echo "Retrieving all global IPv6 addresses..."

printf -v JQ_CMD \
       "ip -json -family inet6  address  show  scope global  primary | %q  --raw-output  %q" \
       "$JQ_TOOLNAME" \
       ".[] | .addr_info[] | .local | select( . != null )"

echo "$JQ_CMD"
readarray -t ALL_GLOBAL_IPV6_ADDRESSES < <( eval "$JQ_CMD" )

if true; then
  echo
  echo "Global IPv6 addresses found:"
  for IPV6_ADDR in "${ALL_GLOBAL_IPV6_ADDRESSES[@]}"; do
    echo "$IPV6_ADDR"
  done
fi

declare -i ALL_GLOBAL_IPV6_ADDRESSES_ELEM_COUNT="${#ALL_GLOBAL_IPV6_ADDRESSES[@]}"

if (( ALL_GLOBAL_IPV6_ADDRESSES_ELEM_COUNT > 1 )); then
abort "There are $ALL_GLOBAL_IPV6_ADDRESSES_ELEM_COUNT global IPv6 addresses, and I do not know which one to use."
fi

echo

declare -r GLOBAL_IPV6_ADDR_TO_USE="${ALL_GLOBAL_IPV6_ADDRESSES[0]}"

# A naked IPv6 address does not work, at least with "x11vnc 0.9.16 lastmod: 2019-01-05"
# which ships with Ubuntu 22.04 . Therefore, always surround the IPv6 address
# with brackets and append the port number.
VNC_CNX_STR="[$GLOBAL_IPV6_ADDR_TO_USE]"

if is_var_set "$PORT_FORWARD_ENV_VAR_NAME"; then

  PORT_FORWARD_VALUE="${!PORT_FORWARD_ENV_VAR_NAME}"

  # Some servers, like x11vnc, use the standard notation "hostname:portnumber", like "localhost:5500".
  #
  # Unfortunately, the VNC world tends to differ. The TightVNC server dialog box for menu option "Attach Listening Viewer..." states:
  #  "To specify a TCP port, append it after 2 colons (myhost:443).
  #   A number of up to 99 after just one colon specifies an offset from the default port 5500"
  # This means that "localhost:1" refers to TCP port 5501, as "1" is taken as a "display number", and not a TCP port number.
  #
  # That makes the port notation ambiguous. After all, we do not know what server the remote user will be using.
  #
  # However, I have tested with TightVNC Server version 2.8.81 (in Application Mode), and it seems to
  # accept the standard notation "hostname:5500" too. Therefore, we only have to be careful here that the port number is > 99.
  #
  # If other servers do not accept port numbers in the same way, we may have to configure or prompt for the format to use,
  # or maybe output several formats at the same time, so that the user chooses the right one.

  declare -r PORT_NUMBER_REGEX="^[0-9]+\$"

  if ! [[ $PORT_FORWARD_VALUE =~ $PORT_NUMBER_REGEX ]]; then
    abort "Environment variable $PORT_FORWARD_ENV_VAR_NAME has value \"$PORT_FORWARD_VALUE\", which does not look like an integer number."
  fi


  # We check the length of the string in order to prevent an eventual integer overflow.
  #
  # We should strip any leading zeros beforehand.

  if (( ${#PORT_FORWARD_VALUE} > 5 || PORT_FORWARD_VALUE > 65535 )); then
    abort "Environment variable $PORT_FORWARD_ENV_VAR_NAME has value \"$PORT_FORWARD_VALUE\", which does not look like a valid TCP port number."
  fi

  if (( PORT_FORWARD_VALUE <= 99 )); then
    abort "Environment variable $PORT_FORWARD_ENV_VAR_NAME has value \"$PORT_FORWARD_VALUE\", but values <= 99 are ambiguous in the VNC world."
  fi

else

  PORT_FORWARD_VALUE="$DEFAULT_REVERSE_VNC_PORT"

fi

printf  -v VNC_PORT_NUMBER_NO_LEADING_ZERO  "%d"  "$PORT_FORWARD_VALUE"

VNC_CNX_STR+=":$VNC_PORT_NUMBER_NO_LEADING_ZERO"


# Note that xsel forks and detaches from the terminal (if it is not just clearing the clipboard).
# xsel then waits indefinitely for other programs to retrieve the text it is holding,
# perhaps multiple times. When something else replaces or deletes the clipboard's contents,
# xsel automatically terminates.

echo -n "$VNC_CNX_STR" | "$XSEL_TOOLNAME" --input --clipboard


echo "Reverse VNC connection string copied to the clipboard: $VNC_CNX_STR"
