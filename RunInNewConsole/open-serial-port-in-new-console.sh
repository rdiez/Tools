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


if [ $# -ne 3 ]; then
  abort "Invalid arguments. Usage example: \"$0\" /dev/ttyS0 115200 \"My Window Title\"" >&2
fi


SERIAL_PORT_FILENAME="$1"
SERIAL_PORT_SPEED="$2"
WINDOW_TITLE="$3"


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


# We could add option "escape=0x03" below (to the STDIO side) in order to make socat
# quit with Ctrl+C, or alternatively "escape=0x0F" in order to quit with Ctrl+O. However,
# leaving this option out seems to pass all such key combinations to the remote device,
# which is usually what you want. In order to terminate socat, you would normally
# close the window with the mouse or with your desktop environment's standard key combination.
#
# See here for more information about the socat options below:
#   www.devtal.de/wiki/Benutzer:Rdiez/SerialPortTipsForLinux
CMD="socat -t0 STDIO,raw,echo=0  $SERIAL_PORT_FILENAME,b$SERIAL_PORT_SPEED,cs8,parenb=0,cstopb=0,clocal=0,raw,echo=0,setlk,flock-ex-nb"

"$RUN_IN_NEW_CONSOLE" \
  --konsole-discard-stderr \
  --konsole-icon=kcmkwm \
  --konsole-title="$WINDOW_TITLE" \
  -- \
  "$CMD"
