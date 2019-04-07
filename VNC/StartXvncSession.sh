#!/bin/bash

# This VNC method creates a virtual X server that has nothing to do with the
# physical X server session on the local monitor.
#
# Installation steps are:
# - Install 'tmux' on the server.
# - Install package 'tigervnc-standalone-server' for TigerVNC,
#        or package 'tightvncserver' for TightVNC.
#   See variable USE_TIGER below.
# - Use tool 'vncpasswd' to set the password used to access VNC desktops.
#   Without such a password, any local user can access the VNC server.
#
#   With TigerVNC we could use UNIX domain sockets, instead of TCP sockets on localhost.
#   SSH can tunnel such sockets too. Linux checks the file permissions of UNIX domain sockets,
#   so you may not need to set a VNC password.
#
# - Copy this script to the remote host.
#
# An existing local session on the host may cause problems starting a new VNC virtual session,
# at least for the same user. If you are not in front of the remote PC,
# terminate the existing local session like this:
#    sudo pkill -TERM -u "$USER"
#  or
#    sudo killall -TERM  -u "$USER"
#  or
#    Find out what the existing root session process is.
#    It should be called something like "xfce4-session".
#    Kill it with signal TERM.
#
# Run this script on the remote host. Use tmux in order for the X server to survive
# an SSH disconnection. For example:
#
#   ssh -t -2 RemoteHost  tmux new-session -A -s RemoteVncDesktopSession  /home/user/StartXvncSession.sh  1  800x600
#
# Another example with run-in-new-console.sh :
#
#   /home/rdiez/rdiez/Tools/RunInNewConsole/run-in-new-console.sh  --console-title="Remote Session" --console-icon="modem" -- "ssh -t -2 RemoteHost  tmux new-session -A -s RemoteVncDesktopSession  /home/user/StartXvncSession.sh  1  800x600"
#
# Because logging out within VNC does not always reliably kill the X server, you can just
# log on to the tmux session and press Ctrl+C to terminate the session.
#
# If you want to connect with Vinagre, create an SSH tunnel first:
# On one terminal:
#   ssh -N -L 5901:localhost:5901 RemoteHost
# On another terminal:
#    vinagre ::5901
#
# Remmina can start the SSH tunnel automatically with these settings:
#
#   Beware that Remmina only works with "High colour (16 bpp)". With "256 colours (8 bpp)" the
#   remote connection window flashes open and then immediately closes.
#
#   Basic settings:
#     Server: localhost:5901
#     User password: VNC server password
#     Colour depth: High colour (16 bpp)
#   SSH Tunnel settings:
#     Enable SSH Tunnel: enabled
#     Custom: RemoteHost:5000  (RemoteHost can be an SSH alias, but the port number must be stated separately here)
#     User name: username  (Necessary, or the connection will hang. Any username in the SSH config will not be honoured.)
#     Select option "Public key (automatic)". Alternatively, select the .key file as the "Identity file".
#
# The Xtightvnc server does not support the xrandr extension, so you cannot change
# the desktop resolution on the fly with xrandr.
# Xtigervnc does support xrandr, but apparently only with fixed resolutions, so it is not much fun to use.
#
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


start_desktop_session ()
{
  # I do not know how to automatically detect the desktop environment.
  # Environment variable XDG_CURRENT_DESKTOP is not available until
  # the desktop environment has started.

  # Xfce Desktop.
  if true; then
    # Or would 'startxfce4' be better?
    xfce4-session
  fi

  # Mate Desktop.
  if true; then
    mate-session
  fi
}


# ------- Entry point -------

declare -r USE_TIGER=true

if (( $# != 2 )); then
  abort "Invalid number of command-line arguments. This tools expects a display number like 1 and a resolution like 800x600."
fi

declare -r DISPLAY_NUMBER="$1"
declare -r DISPLAY_RESOLUTION="$2"


declare -r PASSWORD_FILENAME="$HOME/.vnc/passwd"

if ! test -f "$PASSWORD_FILENAME"; then
  abort "Password file does not exist: $PASSWORD_FILENAME"
fi


unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Just in case the user connected with ssh -X, remove the DISPLAY environment variable.
unset DISPLAY

# Avoid the 'vncserver' Perl wrapper script and start Xtightvnc/Xtigervnc directly.
# The wrapper script makes it hard to control the X server lifetime.

if $USE_TIGER; then
  declare -r SERVER_NAME="Xtigervnc"
else
  declare -r SERVER_NAME="Xtightvnc"
fi

printf -v VNC_SERVER_CMD \
       "%q  -localhost  -rfbauth %q  -desktop RemoteDesktopXvnc  -alwaysshared  -geometry %q -depth 16" \
       "$SERVER_NAME" \
       "$PASSWORD_FILENAME" \
       "$DISPLAY_RESOLUTION"

if $USE_TIGER; then
  VNC_SERVER_CMD+="  -UseIPv6=0"
fi

VNC_SERVER_CMD+="  :$DISPLAY_NUMBER"


echo "Starting the VNC server..."
echo "$VNC_SERVER_CMD"
eval "$VNC_SERVER_CMD" &

declare -r VNC_SERVER_PID="$!"

# Give the X server a little time to start listeting to the network socket.
# Just waiting is rather unfortunate, but I cannot think of an easy way
# to synchronise with the X server initialisation.
sleep 1

export DISPLAY=":$DISPLAY_NUMBER"

# TigerVNC version 1.8.0 no longer needs vncconfig for clipboard support.
if $USE_TIGER; then
  echo "Starting vncconfig..."
  vncconfig -nowin &
  declare -r VNCCONFIG_PID="$!"
fi

# The desktop session process can terminate with a non-zero exit code, for example
# upon reception of SIGTERM, so disable error detection.
set +o errexit

# Note that this starts the desktop session, even though you are not yet connected over VNC.
# This means that the session will start in the background and remain there waiting for you
# to connect.
echo "Starting the desktop session..."
start_desktop_session

set -o errexit


# Killing Xtightvnc/Xtigervnc does not always work reliably,
# especially if the Xfce session logs out before it has started completely.
# I guess Xtightvnc/Xtigervnc is ignoring signals during some period of time,
# and/or is forking a child process. It may have to do with having some windows
# on the desktop with higher privileged or another user, like authentication
# dialogs from polkit.
#
# If this happens, you may have to kill Xtightvnc/Xtigervnc manually.

echo
echo "The desktop session has ended. Killing the VNC server..."
kill  -TERM  "$VNC_SERVER_PID"

echo "Waiting for the VNC server to exit..."
set +o errexit
wait "$VNC_SERVER_PID"
set -o errexit

if $USE_TIGER; then
  echo "Waiting for vncconfig to exit..."
  set +o errexit
  wait "$VNCCONFIG_PID"
  set -o errexit
fi

echo "VNC server has terminated. Remote desktop session terminated."
