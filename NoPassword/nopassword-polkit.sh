#!/bin/bash

# nopassword-polkit.sh version 1.02
#
# This script helps you configure polkit to stop password prompting
# for the privileged actions of your choice.
#
# This works best for GUI applications that use polkit. For command-line tools
# it is best to use companion script 'nopassword-sudo.sh'.
#
# For convenience, set environment variable SUDO_EDITOR, so that 'sudoedit'
# can open the apropriate configuration file in the editor of your choice.
#
# See this web page for more information:
#   https://rdiez.miraheze.org/wiki/Installing_Linux#Preventing_Password_Prompts
#
# Copyright (c) 2018-2023 R. Diez - Licensed under the GNU AGPLv3

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
[My personal settings group 1]

Identity=unix-group:sudo

# - Action 'com.ubuntu.pkexec.synaptic' is for starting "Synaptic Package Manager"
#   with the menu (synaptic-pkexec).
# - Actions 'org.debian.apt.update-cache' and 'org.debian.apt.install-or-remove-packages'
#   are for the "Software Updater" (/usr/bin/update-manager), and probably help
#   with Ubuntu's "Software" or "Software Center" (gnome-software) too.
Action=com.ubuntu.pkexec.synaptic;org.debian.apt.update-cache;org.debian.apt.install-or-remove-packages

# According to the documentation, "ResultInactive" should be for remote users,
# but it does not behave like that, at least on Ubuntu 22.04. In fact, it seems to have
# no effect at all. I am setting it to 'no' just in case.
ResultInactive=no

# "ResultActive" is for local users.
ResultActive=yes

# "ResultAny" is for remote desktop users (like x2go).
# According to the documentation, ResultAny should however be like ResultActive and
# ResultInactive together, but it does not behave like that, at least on Ubuntu 22.04.
# If you know why, please drop me a line.
ResultAny=yes


[My personal settings group 2]

# This group is very similar to the previous one.
# The only reason why there are such separate groups is that the "Action=" line
# was getting too long, which makes editing uncomfortable, especially with
# the simple text editors which sudoedit tends to use.
# The trouble is, I haven't figured out yet whether a setting's value in
# a .pkla file can be split into several lines.

Identity=unix-group:sudo
# - Action 'org.freedesktop.udisks2.filesystem-mount' is for "Disks" (gnome-disks).
# - Action 'org.gsmartcontrol' is for starting 'GSmartControl' with
#   the menu (/usr/bin/gsmartcontrol-root).
#   This tool allows you to view the S.M.A.R.T. disk statistics.
# - Action 'org.gnome.gparted' is for starting the "GParted Partition Editor" (/usr/sbin/gparted).
Action=org.freedesktop.udisks2.filesystem-mount;org.gsmartcontrol;org.gnome.gparted
ResultInactive=no
ResultActive=yes
ResultAny=yes


[My personal settings group 3]
Identity=unix-group:sudo
# - Action 'org.freedesktop.systemtoolsbackends.set' is for package 'gnome-system-tools',
#   which provides tools like "Users and Groups" aka "User Settings" (/usr/bin/users-admin).
# - Action 'org.freedesktop.NetworkManager.settings.modify.own' allows you to edit
#   your network connections with NetworkManager.
Action=org.freedesktop.systemtoolsbackends.set;org.freedesktop.NetworkManager.settings.modify.own
ResultInactive=no
ResultActive=yes
ResultAny=yes


[Allow WLAN scans for all users]
Identity=unix-user:*
# When using a remote desktop, prevent the "System policy prevents Wi-Fi scans" prompt.
Action=org.freedesktop.NetworkManager.wifi.scan
ResultInactive=no
ResultActive=yes
ResultAny=yes
EOF

  set -o errexit

  # Add a new-line at the beginning, for aesthetic purposes only.
  # You cannot do that in the inline text above, as Bash drops any leading new-line characters.
  FILE_TEXT=$'\n'"$FILE_TEXT"

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
#   ./nopassword-polkit.sh: linea 109:  4466 Colgar (hangup)         sudoedit /var/lib/polkit-1/localauthority/10-vendor.d/49-my_personal_no_password_global.pkla
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
