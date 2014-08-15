#!/bin/bash

# If you want to open a serial port in a new console window by clicking on a desktop icon,
# this script will help keeping that desktop icon's properties small and readable.
#
# Besides, if you have several icons for different serial ports, and then you want to
# change the way in which the console windows are created, you will only have to edit
# this one script, and not all icons.
#
# The only drawback is that, if you get the script arguments wrong, or tool 'socat' is not installed,
# any error message will quickly disappear from the screen. Therefore, you may want to test
# the icon's script invocation from a text console first.
#
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3


set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if [ $# -ne 2 ]; then
  abort "Invalid arguments. Usage example: \"$0\" /dev/ttyS0 \"My Window Title\"" >&2
fi


SERIAL_PORT_FILENAME="$1"
WINDOW_TITLE="$2"


SOCAT_TOOL_NAME="socat"

if ! type "$SOCAT_TOOL_NAME" >/dev/null 2>&1 ;
then
  abort "Tool \"$SOCAT_TOOL_NAME\" is not installed on this system."
fi


RUN_IN_NEW_CONSOLE="run-in-new-console.sh"

if ! type "$RUN_IN_NEW_CONSOLE" >/dev/null 2>&1 ;
then
  abort "Tool \"$RUN_IN_NEW_CONSOLE\" not found, check your PATH or edit this script."
fi


CMD="socat STDIO,icanon=0,echo=0,crnl $SERIAL_PORT_FILENAME,b115200,raw,echo=0"

"$RUN_IN_NEW_CONSOLE" \
  --konsole-discard-stderr \
  --konsole-icon=kcmkwm \
  --konsole-title="$WINDOW_TITLE" \
  -- \
  "$CMD"
