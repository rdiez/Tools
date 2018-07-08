#!/bin/bash

# nopassword-sudo.sh version 1.00
#
# This script helps you configure sudo to stop password prompting
# for the sudo commands of your choice.
#
# This works best for command-line tools. For GUI applications that use polkit,
# it is best to use companion script nopassword-polkit.sh .
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


# ------- Entry point -------

if [[ $EUID -eq 0 ]]; then
  abort "This script will run 'sudo' when needed and must not be run as root from the beginning."
fi

if [[ $# -ne 0 ]]; then
  abort "This script takes no command-line arguments."
fi


declare -r BASEDIR="/etc/sudoers.d"
declare -r FILENAME="my_personal_no_password_sudoers"


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
# ALWAYS edit file "/etc/sudoers" with "sudo visudo", or in this case,
# "sudo visudo -f %q",
# because visudo edits the sudoers files in a safe fashion.
# Otherwise, the smallest syntax error can lock you out of the system.
#
# Instead of "%%sudo" below, which makes the rule apply to all users that belong
# to the 'sudo' group, you can specify a particular user account like "mylogin".
#
# The 'ALL' in 'ALL=(root)' is the hostname.
#
# The empty argument ("") below at the end of some commands limits the effect of that
# permissions line to running the application with no arguments.
#
# Note that you cannot give NOPASSWD permissions to any file, like some script
# under your home directory, because sudo seems to carefully check permissions
# along the way. Files under /usr/sbin/ (for example) are fine.
#
# The order of the entries is important, the last one wins.

# Traditional apt-get.
%%sudo ALL=(root) NOPASSWD: /usr/bin/apt-get install *
%%sudo ALL=(root) NOPASSWD: /usr/bin/apt-get update
%%sudo ALL=(root) NOPASSWD: /usr/bin/apt-get upgrade

# From Ubuntu 16.04, you are encouraged to use "apt" instead of "apt-get".
%%sudo ALL=(root) NOPASSWD: /usr/bin/apt install *
%%sudo ALL=(root) NOPASSWD: /usr/bin/apt update
%%sudo ALL=(root) NOPASSWD: /usr/bin/apt upgrade
EOF

  set -o errexit

  # shellcheck disable=SC2059
  printf -v FILE_TEXT_WITH_SUBSTITUTIONS  "$FILE_TEXT"  "$BASEDIR/$FILENAME"

  printf -v CREATE_FILE_CMD  "echo %q >%q && chmod -- 0440 %q"  "$FILE_TEXT_WITH_SUBSTITUTIONS"  "$BASEDIR/$FILENAME"  "$BASEDIR/$FILENAME"

  printf -v CREATE_FILE_CMD_WITH_SUDO "sudo bash -c %q" "$CREATE_FILE_CMD"

  echo "Creating \"$BASEDIR/$FILENAME\"..."

  echo "$CREATE_FILE_CMD_WITH_SUDO"
  eval "$CREATE_FILE_CMD_WITH_SUDO"
  echo

fi


# Step 3) Open the file with visudo.

echo "Opening \"$BASEDIR/$FILENAME\" with visudo for manual editing..."

printf -v VISUDO_CMD  "sudo visudo -f %q"  "$BASEDIR/$FILENAME"

echo "$VISUDO_CMD"
eval "$VISUDO_CMD"

echo
echo "Finished."
