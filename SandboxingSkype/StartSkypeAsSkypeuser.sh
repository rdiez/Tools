#!/bin/bash

# This script helps sandboxing Skype under Ubuntu/Debian.
# See counterpart script StartSkypeInSandbox.sh for more information.
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r LOG_FILENAME="$HOME/SkypeLog.txt"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


is_current_user_member_of_group ()
{
  local GROUPNAME="$1"

  local ALL_GROUPS  # Command 'local' is in a separate line, in order to prevent masking any error from external command 'groups'.
  ALL_GROUPS="$(groups)"

  if false; then
    echo "ALL_GROUPS: $ALL_GROUPS"
  fi

  local REGEXP="\\b${GROUPNAME}\\b"

  if [[ $ALL_GROUPS =~ $REGEXP ]]; then
    return 0
  else
    return 1
  fi
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


check_group_exists ()
{
  local GROUP_NAME="$1"

  if ! [ $(getent group "$GROUP_NAME") ]; then
    abort "Group '$GROUP_NAME' does not exist."
  fi
}


check_tool_exists ()
{
  local TOOL_NAME="$1"

  if ! type "$TOOL_NAME" >/dev/null 2>&1 ; then
     abort "Tool '$TOOL_NAME' not found on this system."
  fi
}


# First of all, check that 'skypeuser' has no sudo access. This would defeat
# the purpose of sandboxing.
#
# There seems to be no script-friendly way to check whether a user can do sudo at all.
# One option I found on the Internet mentions "sudo -v", but that requires entering your password.
# Others are about parsing sudo's text output, which is also not nice.
# Here we just check for memembership of the sudo group.

# The name of the sudo group changes across systems. For example, on FreeBSD this group is called 'wheel'.
SUDO_GROUP_NAME="sudo"

check_group_exists "$SUDO_GROUP_NAME"

if is_current_user_member_of_group "sudo"; then
  abort "User account '$USER' has 'sudo' permission, which it should not have."
fi


# If we download files with Skype, we probably do not want that other users
# can read them.
check_home_dir_permissions


# It is difficult to troubleshoot errors after starting a command in the background with "&".
# If something goes wrong, the user will probably have to look at the log file.
# Therefore, check the most typical errors beforehand, which are not having the necessary
# tools installed on the system.

PUSEAUDIO_TOOL="pulseaudio"
FIREJAIL_TOOL="firejail"
SKYPE_TOOL="skype"

check_tool_exists "$FIREJAIL_TOOL"
check_tool_exists "$SKYPE_TOOL"


"$PUSEAUDIO_TOOL" --start

# The command below starts in the background with "&". Any errors will not make this script
# return a failed status code. If the user is starting this script from a desktop icon,
# even when using run-in-new-console.sh , the console window will close so fast
# the it will be impossible to read any error messages. The user will
# have to look in the log file for error information.
nohup "$FIREJAIL_TOOL" "$SKYPE_TOOL" >"$LOG_FILENAME" 2>&1  &

echo "Skype started. If something goes wrong, see log file $LOG_FILENAME ."
