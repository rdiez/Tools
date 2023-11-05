#!/bin/bash

# This script is designed to help users connect to a listening VNC viewer (so called "reverse VNC connection"),
# like TightVNC on Windows, Vinagre on Linux, or Remmina' VNCI (VNC listener Plugin) on Linux.
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
# Copyright (c) 2017-2023 R. Diez - Licensed under the GNU AGPLv3
#
# Script version 1.5 .

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace this script.

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

# Set here the user language to use. See GetMessage() for a list of language codes available.
declare -r USER_LANGUAGE="eng"


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
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


# Command 'read' does not seem to print any errors if something goes wrong.
# This helper routine always prints an error message in case of failure.

ReadLineFromConfigFile ()
{
  local VARIABLE_NAME="$1"
  local FILENAME="$2"
  local FILE_DESCRIPTOR="$3"

  set +o errexit

  read -r "${VARIABLE_NAME?}" <&"${FILE_DESCRIPTOR}"

  local READ_EXIT_CODE="$?"

  set -o errexit

  if [ $READ_EXIT_CODE -ne 0 ]; then
   abort "Cannot read the next line from configuration file \"$FILENAME\". The file may be corrupt, please delete it and try again."
  fi
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


prompt_for_address ()
{
  declare -r ZENITY_TOOL="zenity"

  verify_tool_is_installed  "$ZENITY_TOOL"  "zenity"

  local PREVIOUS_CONNECTION_FILENAME="$HOME/.$SCRIPT_NAME.lastConnectionParams.txt"
  local PREVIOUS_IP_ADDRESS=""
  local PREVIOUS_TCP_PORT="5500"
  local SUPPORTED_FILE_VERSION="FileFormatVersion=1"

  if [ -e "$PREVIOUS_CONNECTION_FILENAME" ]; then

    local FILE_DESCRIPTOR

    exec {FILE_DESCRIPTOR}<"$PREVIOUS_CONNECTION_FILENAME"

    local FILE_VERSION

    ReadLineFromConfigFile FILE_VERSION "$PREVIOUS_CONNECTION_FILENAME" "$FILE_DESCRIPTOR"

    if [[ $FILE_VERSION != "$SUPPORTED_FILE_VERSION" ]]; then
      abort "File \"$PREVIOUS_CONNECTION_FILENAME\" has an unsupported file format. Please delete it and try again."
    fi

    ReadLineFromConfigFile PREVIOUS_IP_ADDRESS "$PREVIOUS_CONNECTION_FILENAME" "$FILE_DESCRIPTOR"
    ReadLineFromConfigFile PREVIOUS_TCP_PORT   "$PREVIOUS_CONNECTION_FILENAME" "$FILE_DESCRIPTOR"

    exec {FILE_DESCRIPTOR}>&-

  fi


  GetMessage "Prompting the user for the IP address..." \
             "Eingabeaufforderung für die IP-Adresse..." \
             "Solicitando la dirección IP al usuario..."

  local TITLE
  TITLE="$(GetMessage "Reverse VNC connection" \
                      "Umgekehrte VNC Verbindung" \
                      "Conexión VNC inversa" )"

  local HEADLINE_IP_ADDR
  HEADLINE_IP_ADDR="$(GetMessage "Please enter the IP address or hostname to connect to:" \
                                 "Geben Sie bitte die IP-Addresse oder den Hostnamen des entfernten Rechners ein:" \
                                 "Introduzca la dirección IP o el nombre del equipo remoto:" )"
  set +o errexit

  # Unfortunately, Zenity's --forms option, as of version 3.8.0, does not allow setting a default value in a text field.
  # However, that is often very comfortable. Therefore, prompt the user twice. This is the first dialog.
  # On second thought, the user could just write all together in a single text field, like "127.0.0.1:5500".
  local IP_ADDRESS
  IP_ADDRESS="$("$ZENITY_TOOL" --no-markup  --entry  --title "$TITLE"  --text "$HEADLINE_IP_ADDR"  --entry-text="$PREVIOUS_IP_ADDRESS")"

  local -r ZENITY_EXIT_CODE_1="$?"

  set -o errexit

  if [ $ZENITY_EXIT_CODE_1 -ne 0 ]; then
    GetMessage "The user cancelled the dialog." \
               "Der Benutzer hat das Dialogfeld abgebrochen." \
               "El usuario canceló el cuadro de diálogo."
    exit 0
  fi

  # Save the user-entered IP address now, just in case the user cancels the next dialog.
  # We need to save the whole file, or we will get an error next time around.
  printf "%s\\n%s\\n%s\\n" \
         "$SUPPORTED_FILE_VERSION" \
         "$IP_ADDRESS" \
         "$PREVIOUS_TCP_PORT" \
         >"$PREVIOUS_CONNECTION_FILENAME"

  if [[ $IP_ADDRESS = "" ]]; then
    abort "$(GetMessage "No IP address entered." \
                        "Keine IP-Adresse eingegeben." \
                        "No se ha introducido ninguna dirección IP." )"
  fi


  GetMessage "Prompting the user for the TCP port..." \
             "Eingabeaufforderung für den TCP-Port..." \
             "Solicitando el puerto TCP al usuario..."

  local HEADLINE_TCP_PORT
  HEADLINE_TCP_PORT="$(GetMessage "Please enter the TCP port number to connect to:" \
                                  "Geben Sie bitte die TCP-Portnummer auf dem entfernten Rechner ein:" \
                                  "Introduzca el número de puerto TCP al que conectarse:" )"
  set +o errexit

  local TCP_PORT
  TCP_PORT="$("$ZENITY_TOOL" --no-markup  --entry  --title "$TITLE"  --text "$HEADLINE_TCP_PORT"  --entry-text="$PREVIOUS_TCP_PORT")"

  local -r ZENITY_EXIT_CODE_2="$?"

  set -o errexit

  if [ $ZENITY_EXIT_CODE_2 -ne 0 ]; then
    GetMessage "The user cancelled the dialog." \
               "Der Benutzer hat das Dialogfeld abgebrochen." \
               "El usuario canceló el cuadro de diálogo."
    exit 0
  fi

  printf "%s\\n%s\\n%s\\n"  "$SUPPORTED_FILE_VERSION"  "$IP_ADDRESS"  "$TCP_PORT"  >"$PREVIOUS_CONNECTION_FILENAME"

  if [[ $TCP_PORT = "" ]]; then
    abort "$(GetMessage "No TCP port entered." \
                        "Kein TCP-Port wurde eingegeben." \
                        "No se ha introducido ningún puerto TCP." )"
  fi

  IP_ADDRESS_AND_PORT="$IP_ADDRESS:$TCP_PORT"
}


# ----------- Entry point -----------

declare -r X11VNC_TOOL="x11vnc"

verify_tool_is_installed  "$X11VNC_TOOL"  "x11vnc"


if (( $# == 0 )); then

  prompt_for_address

elif (( $# == 1 )); then

  IP_ADDRESS_AND_PORT="$1"

else

  abort "Wrong number of command-line arguments."

fi


# -------- Prepare the x11vnc command --------

CMD="$X11VNC_TOOL"

# We could add a command-line argument to make '-viewonly' optional.
if false; then
  CMD+=" -viewonly"
fi


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


printf -v IP_ADDRESS_AND_PORT_QUOTED "%q" "$IP_ADDRESS_AND_PORT"
CMD+=" -connect_or_exit $IP_ADDRESS_AND_PORT_QUOTED"


GetMessage "Connecting with the following command:" \
           "Verbindungsaufbau mit folgendem Befehl:" \
           "Conectando con el siguiente comando:"

echo "$CMD"
eval "$CMD"
