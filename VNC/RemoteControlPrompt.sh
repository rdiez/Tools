#!/bin/bash

# This script is designed to help users connect to a listening TightVNC viewer.
#
# The user needs to install tools 'x11vnc' and 'zenity' beforehand.
#
# Depending on the user, set USER_LANGUAGE below.
#
# If the user will be running this script from a desktop icon (by double-clicking on it).
# it is best to wrap it with run-in-new-console.sh , which is also in the same
# Git repository as this script. This way, if something fails, the user will see
# the error message at the end.
#
# Maybe the user should disable all desktop effects before the connection.
# Otherwise, the remote control session may turn out to be rather slow.
#
# Still to do is some sort of encryption, like for example SSH tunneling.
# Until then, the whole session is transmitted in clear text over the Internet.
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3
#
# Script version 1.0 .

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_FILENAME="RemoteControlPrompt.sh"


# Set here the user language to use. See GetMessage() for a list of language codes available.
USER_LANGUAGE="eng"

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


GetMessage ()
{
  case "$USER_LANGUAGE" in
    eng) echo "$1";;
    deu) echo "$2";;
    spa) echo "$3";;
    *) abort "Invalid language."
  esac
}


ZENITY_TOOL="zenity"

if ! type "$ZENITY_TOOL" >/dev/null 2>&1 ;
then
  abort "Tool '$ZENITY_TOOL' is not installed."
fi


X11VNC_TOOL="x11vnc"

if ! type "$X11VNC_TOOL" >/dev/null 2>&1 ;
then
  abort "Tool '$X11VNC_TOOL' is not installed. Under Ubuntu/Debian the package name is 'x11vnc'."
fi


PREVIOUS_IP_ADDRESS_FILENAME="$HOME/.$SCRIPT_FILENAME.lastIpAddress.txt"
PREVIOUS_IP_ADDRESS=""

if [ -e "$PREVIOUS_IP_ADDRESS_FILENAME" ]; then
  PREVIOUS_IP_ADDRESS="$(<$PREVIOUS_IP_ADDRESS_FILENAME)"
fi


echo "$(GetMessage "Prompting the user for the IP address..." \
                   "Eingabeaufforderung für die IP-Adresse..." \
                   "Solicitando la dirección IP al usuario..." )"

TITLE="$(GetMessage "Enter the IP address or hostname to connect to" \
                    "IP-Addresse oder Hostnamen des entfernten Rechners eingeben" \
                    "Introduzca la dirección IP o el nombre del equipo remoto" )"
set +o errexit

IP_ADDRESS="$("$ZENITY_TOOL" --entry --title "$TITLE" --text "$TITLE" --entry-text="$PREVIOUS_IP_ADDRESS")"

ZENITY_EXIT_CODE="$?"

set -o errexit

if [ $ZENITY_EXIT_CODE -ne 0 ]; then
  echo "$(GetMessage "The user cancelled the dialog." "Der Benutzer hat das Dialogfeld abgebrochen." "El usuario canceló el cuadro de diálogo.")"
  exit 0
fi

echo "$IP_ADDRESS" >"$PREVIOUS_IP_ADDRESS_FILENAME"


if [[ $IP_ADDRESS = "" ]]; then
  abort "$(GetMessage "No IP address entered." \
                      "Keine IP-Adresse eingegeben." \
                      "No se ha introducido ninguna dirección IP." )"
fi


# -------- Prepare the x11vnc command --------

CMD="$X11VNC_TOOL"


# Option "-tightfilexfer" turns on support for TightVNC's file transfer feature.
# We are assuming that the listening VNC viewer is TightVNC, or at least supports the TightVNC file transfer protocol.
CMD+=" -tightfilexfer"


# Disable the big warning message when you use x11vnc without some sort of password.
CMD+=" -nopw"


# Disable all listening TCP ports. We just want to make a single outgoing connection.
CMD+=" -rfbport 0"


# Option "-noxdamage" attempts to fix some problems with compositing window managers.
# It is probably best if the user disabled desktop effects beforehand.
CMD+=" -noxdamage"


# Exit after the first successfully connected viewer disconnects.
CMD+=" -once"


# If the remote IP address does exist, but drops all packets, x11vnc will wait for too long.
# If the user happened to enter the wrong IP address, the user has to manually close it,
# once he loses patience.
#
# With this timeout, we do not wait for so long. 3 seconds should be enough to establish a connection.
# Lamentably, x11vnc does not set a non-zero exit code when it quits due to a timeout.
#
# Note that you cannot use this option together with "-accept popup:0",
# because the timeout does not stop while prompting the user. If the timeout triggers while the user
# is being prompted, x11vnc version 0.9.13 freezes in such a way, that only SIGKILL will close it.
#
# In the end, I have decided not to use this option. The reason is the zero exit code.
# If the user types the wrong IP address, and is starting this script from a desktop icon
# with the run-in-new-console.sh, a timeout will make the window exit and there is not indication
# about what went wrong.
#   CMD+=" -timeout 3"


# This option is an experimental caching feature. Apparently, it works by creating a
# larger display area, so that the client has to be careful to leave the extra desktop
# area not visible (scrolled off at the bottom). It actually looks like a poor hack.
# It does not work well if TightVNC's "Scale" option is set to "auto".
#   CMD+=" -ncache 10"


printf -v IP_ADDRESS_QUOTED "%q" "$IP_ADDRESS"
CMD+=" -connect_or_exit $IP_ADDRESS_QUOTED"


echo "$(GetMessage "Connecting with the following command:" \
                   "Verbindungsaufbau mit folgendem Befehl:" \
                   "Conectando con el siguiente comando:" )"
echo "$CMD"
eval "$CMD"
