#!/bin/bash

# This script helps sandboxing Skype under Ubuntu/Debian.
# See http://rdiez.shoutwiki.com for more information.
#
# Before running this script, you need to place its counterpart StartSkypeAsSkypeuser.sh
# in the home directory of the 'skypeuser' account. Remember to transfer
# ownership of that script to 'skypeuser' and to keep (or set) its execute bit.
# For example:
#  sudo cp StartSkypeAsSkypeuser.sh ~skypeuser/StartSkypeAsSkypeuser.sh
#  sudo chown skypeuser:skypegroup ~skypeuser/StartSkypeAsSkypeuser.sh
#
# If you are starting this script from a desktop icon, it is best to use run-in-new-console.sh
# to start it. This way, if something goes wrong, you have a good change of seeing the
# corresponding error message. You will find run-in-new-console.sh
# in the same repository as this script
#
# This may work in the future, but it is not implemented yet:
#   Set environment variables SKYPE_USER and SKYPE_PASSWORD beforehand in order to automate logging in.
#
# Copyright (c) 2017-2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace this script, for debugging purposes.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


check_home_dir_permissions ()
{
  local PERMISSIONS  # Command 'local' is in a separate line, in order to prevent masking any error from external command 'stat'.
  PERMISSIONS="$(stat --format="%a" "$HOME")"

  if false; then
    echo "PERMISSIONS: $PERMISSIONS"
  fi

  local -i PERMISSIONS_LEN="${#PERMISSIONS}"

  if (( PERMISSIONS_LEN != 3 )); then
    abort "Unexpected file permissions $PERMISSIONS ."
  fi

  local -i PERMISSIONS_OTHER="${PERMISSIONS:2:1}"

  if (( PERMISSIONS_OTHER != 0 )); then
    abort "Every other user account can access the home directory of user '$USER', which is normally a bad idea."
  fi
}


check_home_dir_permissions

xhost +SI:localuser:skypeuser

pax11publish -r

# Instead of a script, you can run the commands directly from here:
#
#   sudo  --user=skypeuser  --set-home  bash -c  "cd \$HOME  &&  pulseaudio --start  &&  { nohup firejail skypeforlinux >\$HOME/SkypeLog.txt 2>&1 & }"
#
# Redirecting stderr to stdout above is not really necessary, because nohup would do it automatically,
# but doing it manually prevents nohup from printing a warning message about this automatic redirection.

# In order to prevent sudo from prompting for a password when running the
# command below edit file "/etc/sudoers" with "sudo visudo" and add this line:
#   %sudo ALL=(skypeuser) NOPASSWD:SETENV: /home/skypeuser/StartSkypeAsSkypeuser.sh

printf  -v CMD  "sudo --user=%q  --set-home  --preserve-env=SKYPE_USER,SKYPE_PASSWORD  ~skypeuser/StartSkypeAsSkypeuser.sh"  "skypeuser"
echo "$CMD"
eval "$CMD"
