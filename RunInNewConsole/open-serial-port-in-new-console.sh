#!/bin/bash

# If you want to open a serial port in a new console window by clicking on a desktop icon,
# this script will help:
# - You can edit this script in order to change the way all icons open serial ports.
# - This script can open a serial port with many different tools, so you can experiment
#   until you find the right one for you.
#
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3


set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

SCRIPT_NAME="open-serial-port-in-new-console.sh"

PATH_TO_RUN_IN_NEW_CONSOLE_SCRIPT="./run-in-new-console.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


check_whether_tool_exists ()
{
  local TOOL_NAME="$1"

  if ! type "$TOOL_NAME" >/dev/null 2>&1 ;
  then
    abort "Tool \"$TOOL_NAME\" is not installed on this system. Install the tool, check your PATH or modify this script."
  fi
}


escape_filename_for_socat ()
{
  local FILENAME="$1"

  # Escaping of the backslash character ('\') only works separately and must be done first.
  FILENAME="${FILENAME//\\/\\\\}"

  local CHARACTERS_TO_ESCAPE=":,({['!\""

  local -i CHARACTERS_TO_ESCAPE_LEN="${#CHARACTERS_TO_ESCAPE}"
  local -i INDEX

  for (( INDEX = 0 ; INDEX < CHARACTERS_TO_ESCAPE_LEN ; ++INDEX )); do

    local CHAR="${CHARACTERS_TO_ESCAPE:$INDEX:1}"

    FILENAME="${FILENAME//$CHAR/\\$CHAR}"

  done

  ESCAPED_SOCAT_FILENAME="$FILENAME"
}


open_with_socat ()
{
  # We could add option "escape=0x03" below (to the STDIO side) in order to make socat
  # quit with Ctrl+C, or alternatively "escape=0x0F" in order to quit with Ctrl+O. However,
  # leaving this option out seems to pass all such key combinations to the remote device,
  # which is usually what you want. In order to terminate socat, you would normally
  # close the window with the mouse or with your desktop environment's standard key combination.
  #
  # See here for more information about the socat options below:
  #   http://rdiez.shoutwiki.com/wiki/Serial_Port_Tips_for_Linux

  local SOCAT_TOOL_NAME="socat"
  check_whether_tool_exists "$SOCAT_TOOL_NAME"

  escape_filename_for_socat "$SERIAL_PORT_FILENAME"

  # Escape again for the Bash shell.
  printf -v ESCAPED_SOCAT_FILENAME "%q" "$ESCAPED_SOCAT_FILENAME"

  CMD="socat -t0 STDIO,raw,echo=0  file:$ESCAPED_SOCAT_FILENAME,b$SERIAL_PORT_SPEED,cs8,parenb=0,cstopb=0,clocal=0,raw,echo=0,setlk,flock-ex-nb,nonblock=1"
}


open_with_picocom ()
{
  # About picocom:
  # - Exit with Ctrl+A, Ctrl+X.
  # - The serial port file gets locked, so opening a second picocom on the same serial port does not work.
  #   However, this does not block a second connection with socat "setlk,flock-ex-nb", although socat
  #   will eventually display messages like "Resource temporarily unavailable".
  # - There is a short delay on exit.
  local PICOCOM_TOOL_NAME="picocom"
  check_whether_tool_exists "$PICOCOM_TOOL_NAME"

  # Escape the filename for the Bash shell.
  printf -v SERIAL_PORT_FILENAME "%q" "$SERIAL_PORT_FILENAME"

  CMD="\"$PICOCOM_TOOL_NAME\"  --baud \"$SERIAL_PORT_SPEED\"  --flow n  --parity n  --databits 8  \"$SERIAL_PORT_FILENAME\""
}


open_with_minicom ()
{
  # About minicom:
  # - Exit with Ctrl+A, x.
  # - The serial port file gets locked, so opening a second minicom on the same serial port does not work.
  #   However, this does not block a second connection with socat "setlk,flock-ex-nb".

  local MINICOM_TOOL_NAME="minicom"
  check_whether_tool_exists "$MINICOM_TOOL_NAME"

  # Escape the filename for the Bash shell.
  printf -v SERIAL_PORT_FILENAME "%q" "$SERIAL_PORT_FILENAME"

  CMD="\"$MINICOM_TOOL_NAME\" -b \"$SERIAL_PORT_SPEED\" -8 -D \"$SERIAL_PORT_FILENAME\""
}


open_with_screen ()
{
  # About GNU Screen:
  # - Exit with Ctrl+A, '\' , or with Ctrl+A, 'k'.
  # - The serial port file gets locked, so opening a second 'screen' on the same serial port does not work.
  #   You get no proper error message though.

  local SCREEN_TOOL_NAME="screen"
  check_whether_tool_exists "$SCREEN_TOOL_NAME"

  # If you are an experienced GNU Screen user, you may want to attach to an existing session and so on.
  # But if you just want to use GNU Screen as a simple terminal emulator, you want it to exit (and not detach
  # and stay in the background) when you close the window.
  # To achieve that, we need to feed GNU Screen with a temporary configuration file that contains the right option.
  # I tried bash' "Process Substitution", but it did not work.

  local TMP_FILENAME
  TMP_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.screen.cfg")"
  trap "rm \"$TMP_FILENAME\"" EXIT
  echo "autodetach off" >>"$TMP_FILENAME"

  # Escape the filename for the Bash shell.
  printf -v SERIAL_PORT_FILENAME "%q" "$SERIAL_PORT_FILENAME"

  CMD="\"$SCREEN_TOOL_NAME\" -c \"$TMP_FILENAME\" \"$SERIAL_PORT_FILENAME\"  \"$SERIAL_PORT_SPEED\" "
}


open_with_ckermit ()
{
  # About C-Kermit:
  # - Exit with Ctrl+'\', then press uppercase 'C', command "exit". Getting Ctrl+'\' to work on a German keyboard is tricky: press Ctrl+AltGr+'\'.
  # - The serial port file gets locked, so opening a second 'screen' on the same serial port does not work.
  #   Kermit command execution not abort though.

  local CKERMIT_TOOL_NAME="kermit"
  check_whether_tool_exists "$CKERMIT_TOOL_NAME"

  # Escape the filename for the Bash shell.
  printf -v SERIAL_PORT_FILENAME "%q" "$SERIAL_PORT_FILENAME"

  local KERMIT_COMMANDS="set modem type none,set line $SERIAL_PORT_FILENAME,set carrier-watch off,set speed $SERIAL_PORT_SPEED,connect"
  local KERMIT_COMMANDS_QUOTED
  printf -v KERMIT_COMMANDS_QUOTED "%q" "$KERMIT_COMMANDS"

  CMD="\"$CKERMIT_TOOL_NAME\" -C $KERMIT_COMMANDS_QUOTED"
}


open_with_gtkterm ()
{
  # About gtkterm:
  # - The serial port file gets locked, so opening a second 'gtkterm' on the same serial port does not work.
  #   This does not prevent gtkterm from starting and staying open though.
  # - It can display hex codes.

  local GTKTERM_TOOL_NAME="gtkterm"
  check_whether_tool_exists "$GTKTERM_TOOL_NAME"

  # Escape the filename for the Bash shell.
  printf -v SERIAL_PORT_FILENAME "%q" "$SERIAL_PORT_FILENAME"

  CMD="\"$GTKTERM_TOOL_NAME\"  --port \"$SERIAL_PORT_FILENAME\"  --speed \"$SERIAL_PORT_SPEED\" "

  NEEDS_NEW_CONSOLE_WINDOW=false
}


# ----------- Entry point -----------

if [ $# -ne 4 ]; then
  abort "Invalid arguments. Usage example: \"$0\" /dev/ttyS0 115200 socat \"My Window Title\"" >&2
fi


# These are the command-line arguments the user needs to supply:

SERIAL_PORT_FILENAME="$1"
SERIAL_PORT_SPEED="$2"
OPEN_WITH="$3"
WINDOW_TITLE="$4"


NEEDS_NEW_CONSOLE_WINDOW=true

case "$OPEN_WITH" in
  socat)   open_with_socat;;
  picocom) open_with_picocom;;
  minicom) open_with_minicom;;
  screen)  open_with_screen;;
  ckermit) open_with_ckermit;;
  gtkterm) open_with_gtkterm;;
  *) abort "Unknown method \"$OPEN_WITH\".";;
esac

if $NEEDS_NEW_CONSOLE_WINDOW; then

  check_whether_tool_exists "$PATH_TO_RUN_IN_NEW_CONSOLE_SCRIPT"

  echo "Running this command in new console: $CMD"

  printf -v CMD_QUOTED "%q" "$CMD"

  CMD_NEW_CONSOLE="\"$PATH_TO_RUN_IN_NEW_CONSOLE_SCRIPT\""
  CMD_NEW_CONSOLE+=" --console-discard-stderr"
  CMD_NEW_CONSOLE+=" --console-icon=kcmkwm"
  CMD_NEW_CONSOLE+=" --console-title=\"$WINDOW_TITLE\""
  if false; then
    CMD_NEW_CONSOLE+=" --console-no-close"
  fi
  CMD_NEW_CONSOLE+=" -- "
  CMD_NEW_CONSOLE+=" $CMD_QUOTED"

  echo "$CMD_NEW_CONSOLE"
  eval "$CMD_NEW_CONSOLE"

else

  echo "$CMD"
  eval "$CMD"

fi
