#!/bin/bash

# This script implements a remote Linux desktop to a with following steps:
# 1) Start a nested X server in a window with Xephyr.
# 2) Connect to a remote host with SSH.
# 3) Start new a desktop environment session on the remote server, which is then
#   displayed on the nested X server window.
#
# Such a remote desktop solution has drawbacks:
# - Xephir has no built-in clipboard sharing, which is a pain.
#   There are various external scripts with more or less issues.
# - An X server connection performs poorly over the Internet.
#   Latency adds up and often causes long pauses.
#   It is only fun on a fast, local network.
# - The handling of keyboard layouts is problematic.
#   It works best if you have the same keyboard layout on both the local
#   and the remote host.
# - Logging out of the session does not work on Ubuntu MATE 18.04.2,
#   or it does not terminate the SSH connection on Xubuntu 18.04.2.
# - Closing the Xephyr often does not terminate the SSH connection.
# - If you lose the SSH connection, the desktop session is lost.
#
#  Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}

# ------- Entry point -------

if (( $# != 2 )); then
  abort "Invalid number of command-line arguments. This tools expects the remote SSH server name and a display number like 1."
fi

REMOTE_SSH_HOSTNAME="$1"
DISPLAY_NUMBER="$2"

Xephyr  -ac  -br  -screen 800x600  -resizeable  -reset -terminate  ":$DISPLAY_NUMBER"  &

# The options above mean:
#   -ac              Disable access control restrictions (allows you to forward X)
#   -screen 800x600  Sets the default window size
#   -resizeable      Makes the screen (for the guest) and the window (for the host) resizeable
#   -br              Sets the default root window to solid black instead of the standard root weave pattern.
#                    Although I could not see any difference without this option.
#   -reset           Reset after last client exists
#   -terminate       Terminate Xephyr at server reset (does not always work)


# We should wait here until the X server has started listening on the TCP port,
# but I could not find an easy way to do that.
# I would say that Xephyr is missing something equivalent to ssh's combination of '-f' and 'ExitOnForwardFailure'.


# The X server listens on TCP port 6000 + D, where D is the display number.
#
# The syntax for the DISPLAY environment variable is:  hostname:D.S
# - The default for hostname is 'localhost'.
# - D is the display number, usually 0.
# - S is the screen number (for multiple monitors). The default is 0.
#
# Using DISPLAY=localhost:1.0 here yields the same DISPLAY on the remote system, but then it no longer works.
# I guess that ssh gets somehow confused.

export DISPLAY=":$DISPLAY_NUMBER.0"


CMD=""


# Environment variable DBUS_SESSION_BUS_ADDRESS has normally a value like this on the remote system:
#
#   unix:path=/run/user/1000/bus
#
# If the user is already logged on on the remote host, and you try to run mate-session again,
# you get a dialog box with the following error message:
#
#   Could not acquire name on session bus
#
# As a work-around, you can delete the DBUS_SESSION_BUS_ADDRESS environment variable.
# The new session will set this variable to something like:
#
#   unix:abstract=/tmp/dbus-Bu4OYHdSFn,guid=f7abf2c2b9d6766557e8af8751165edd

if false; then
  CMD+="unset DBUS_SESSION_BUS_ADDRESS && "
fi


# I do not know how to automatically detect the desktop environment.
# Environment variable XDG_CURRENT_DESKTOP is not available until
# the desktop environment has started.

# CMD+="mate-session"
CMD+="xfce4-session"


# Enabling SSH compression provides a big performance boost when connecting over the Internet.

ssh  -X  -o "ExitOnForwardFailure=yes"  -o "Compression=yes"  "$REMOTE_SSH_HOSTNAME"  "$CMD"
