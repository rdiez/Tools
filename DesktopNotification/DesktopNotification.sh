#!/bin/bash

# This script displays a simple desktop notification.
# I use it for example from KTimer to alert me when a timer has expired.
#
# KTimer's command parsing is tricky. This is the command I am using:
#   bash -c "$HOME/rdiez/Tools/DesktopNotification/DesktopNotification.sh 'Timer expired.'"

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


# Some desktops, like KDE, provide notifications that stay until you click them away. Then
# you may want to disable the pop-up message window notification.
# You should not disable this under Microsoft Windows, because taskbar notifications are not implemented yet on Windows.

ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION=true


NOTIFY_SEND_TOOL="notify-send"

UNIX_MSG_TOOL="gxmessage"


if [ $# -ne 1 ]; then
  abort "You need to pass a single argument with the notification message."
fi

MESSAGE="$1"

if [[ $OSTYPE = "cygwin" ]]; then
  # Script background.sh has code for Windows/Cygwin, but I haven't ported it to this script yet.
  abort "Not supported yet."
fi

command -v "$UNIX_MSG_TOOL" >/dev/null 2>&1  ||  abort "Tool '$UNIX_MSG_TOOL' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu the associated package is called \"gxmessage\", and its description is \"an xmessage clone based on GTK+\"."

command -v "$NOTIFY_SEND_TOOL" >/dev/null 2>&1  ||  abort "Tool '$NOTIFY_SEND_TOOL' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu the associated package is called \"libnotify-bin\"."


"$NOTIFY_SEND_TOOL" --icon=dialog-information -- "$MESSAGE"

if $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION; then
  echo "Waiting for the user to close the notification message box window..."
  # Remember that, if the user closes the window without pressing the OK button, the exit status is non-zero.
  # That is the reason why there is a "|| true" at the end.
  echo -e "$MESSAGE" | "$UNIX_MSG_TOOL" -title "$MESSAGE" -file - || true
fi

echo "Finished notifying."
