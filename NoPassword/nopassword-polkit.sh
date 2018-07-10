#!/bin/bash

# nopassword-polkit.sh version 1.01
#
# This script helps you configure polkit to stop password prompting
# for the privileged actions of your choice.
#
# This works best for GUI applications that use polkit. For command-line tools
# it is best to use companion script nopassword-sudo.sh .
#
# Make sure you have set environment variable SUDO_EDITOR, so that 'sudoedit'
# can open the apropriate configuration file for you to edit.
#
# See this web page for more information:
#   http://rdiez.shoutwiki.com/wiki/Installing_Linux#Preventing_Password_Prompts
#
# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


# sighup_handler ()
# {
#   # This code never runs. I do not know why yet.
#   # I left this code in place so that I notice in the future  when this routine does get called.
#   echo "SIGHUP received."
# }


# ------- Entry point -------

if [[ $EUID -eq 0 ]]; then
  abort "This script will run 'sudo' when needed and must not be run as root from the beginning."
fi

if [[ $# -ne 0 ]]; then
  abort "This script takes no command-line arguments."
fi


# In the future, we may have to switch from a .pkla file (with a declarative syntax)
# to a .rules file (with JavaScript).

declare -r BASEDIR="/var/lib/polkit-1/localauthority/10-vendor.d"
declare -r FILENAME="49-my_personal_no_password_global.pkla"


# Step 1) Check whether the config file exists.

set +o errexit

read -r -d '' CHECK_CMD_TEMPLATE <<'EOF'
  if [[ -d %q ]]; then
    if [[ -f %q ]]; then
      echo 2
    else
      echo 3
    fi
  else
    echo 1
  fi
EOF

set -o errexit


# shellcheck disable=SC2059
printf -v CHECK_CMD  "$CHECK_CMD_TEMPLATE"  "$BASEDIR"  "$BASEDIR/$FILENAME"

printf -v CHECK_CMD_WITH_SUDO "sudo bash -c %q" "$CHECK_CMD"

echo "Checking whether \"$BASEDIR/$FILENAME\" exists..."

echo "$CHECK_CMD_WITH_SUDO"
CHECK_RESULT="$(eval "$CHECK_CMD_WITH_SUDO")"
echo

case "$CHECK_RESULT" in
  1) abort "Directory \"$BASEDIR\" does not exist. This script has only been tested on Debian/Ubuntu 16.04/18.04 systems.";;
  2) CREATE_FILE=false;;
  3) CREATE_FILE=true;;
  *) abort "Unexpected return value.";;
esac


# Step 2) Create the config file if necessary.

if $CREATE_FILE; then

  set +o errexit

  read -r -d '' FILE_TEXT <<'EOF'
[My personal no password prompt for sudoers for the actions listed below]
Identity=unix-group:sudo
Action=com.ubuntu.pkexec.synaptic;org.freedesktop.systemtoolsbackends.set;org.debian.apt.install-or-remove-packages
ResultActive=yes
EOF

  set -o errexit


  printf -v CREATE_FILE_CMD  "echo %q >%q"  "$FILE_TEXT"  "$BASEDIR/$FILENAME"

  printf -v CREATE_FILE_CMD_WITH_SUDO "sudo bash -c %q" "$CREATE_FILE_CMD"

  echo "Creating \"$BASEDIR/$FILENAME\"..."

  echo "$CREATE_FILE_CMD_WITH_SUDO"
  eval "$CREATE_FILE_CMD_WITH_SUDO"
  echo

fi


# Step 3) Open the file with sudoedit.

echo "Opening \"$BASEDIR/$FILENAME\" with sudoedit for manual editing..."

printf -v SUDOEDIT_CMD  "sudoedit %q"  "$BASEDIR/$FILENAME"
echo "$SUDOEDIT_CMD"


# Version 1.8.16 of sudo/sudoedit that ships with Ubuntu 16.04 has the following bug:
#
#   A change made in sudo 1.8.15 inadvertantly caused sudoedit to
#   send itself SIGHUP instead of exiting when the editor returns
#   an error or the file was not modified.
#
# That bug was fixed in sudo 1.8.21.
#
# With the buggy versions, and without the following 'trap' command, you get this kind
# of message (the system is localized to Spain):
#   sudoedit: /var/lib/polkit-1/localauthority/10-vendor.d/49-my_personal_no_password_global.pkla unchanged
#   ./nopassword-polkit.sh: línea 109:  4466 Colgar (hangup)         sudoedit /var/lib/polkit-1/localauthority/10-vendor.d/49-my_personal_no_password_global.pkla
# That seems to indicate that the current Bash instance does receive the SIGHUP signal.
# With the following 'trap' command, we cannot actually run any code in this shell when the trap is sent/received
# (function sighup_handler is never actually called), I do not know why yet. But at least the received signal message is shorter.
#   trap "sighup_handler" HUP
# After installing the trap, this is what the printed message looks like:
#   sudoedit: /var/lib/polkit-1/localauthority/10-vendor.d/49-my_personal_no_password_global.pkla unchanged
#   Colgar (hangup)
# Using 'trap "" HUP' in order to ignore the signal has the same effect: the message is just shorter.

# When the child process dies because of SIGHUP, it yields a non-zero exit code.
set +o errexit

eval "$SUDOEDIT_CMD"
declare -i SUDOEDIT_CMD_EXIT_CODE="$?"

set -o errexit

# trap - HUP


declare -r -i SIGHUP_NUMBER=1

if (( SUDOEDIT_CMD_EXIT_CODE == 128 + SIGHUP_NUMBER )); then
  echo "sudoedit terminated because of SIGHUP (which is probably due to a sudo bug in versions >= 1.8.15 and < 1.8.21, but it is still OK)."
else
  if (( SUDOEDIT_CMD_EXIT_CODE != 0 )); then
    abort "The command failed. Did you set environment SUDO_EDITOR properly?"
  fi
fi

echo
echo "Finished."
