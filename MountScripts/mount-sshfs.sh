#!/bin/bash

# Version 1.04.
#
# This is the kind of script I use to conveniently mount and unmount an SSHFS
# filesystem on a remote host.
#
# You will need to edit variables REMOTE_PATH etc. below in this script.
#
# Optionally set environment variable OPEN_FILE_EXPLORER_CMD to control how
# to open a file explorer window on the just-mounted filesystem.
#
# Afterwards, use this script to mount and dismount the hard-coded path with a minimum of fuss:
#
#   mount-sshfs.sh
#     or
#   mount-sshfs.sh mount-no-open
#
# and afterwards:
#
#   mount-sshfs.sh umount
#     or
#   mount-sshfs.sh unmount
#
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r REMOTE_PATH="MyFriendlySshHostName:/home/some/path"
declare -r LOCAL_MOUNT_POINT="$HOME/MountPoints/some/path"


# --- You probably will not need to modify anything after this point ---


declare -r -i EXIT_CODE_ERROR=1
declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r SSHFS_TOOL="sshfs"

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit "$EXIT_CODE_ERROR"
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
  local -a FILES
  FILES=( "$1"/* )

  if [ ${#FILES[@]} -eq 0 ]; then
    return $BOOLEAN_TRUE
  else
    if false; then
      echo "Files found: ${FILES[*]}"
    fi
    return $BOOLEAN_FALSE
  fi
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


printf -v CMD_UNMOUNT \
       "fusermount -u -z -- %q" \
       "$LOCAL_MOUNT_POINT"


do_mount ()
{
  local -r SHOULD_OPEN_AFTER_MOUNTING="$1"

  mkdir --parents -- "$LOCAL_MOUNT_POINT"

  if ! is_dir_empty "$LOCAL_MOUNT_POINT"; then
    abort "Mount point \"$LOCAL_MOUNT_POINT\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
  fi

  verify_tool_is_installed "$SSHFS_TOOL" "sshfs"

  local SSHFS_OPTIONS=""
  SSHFS_OPTIONS+=" -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 "

  # Option 'auto_cache' means "enable caching based on modification times", it can improve performance but maybe risky.
  # Option 'kernel_cache' could improve performance.
  # Option 'compression=no' improves performance if you are largely transferring encrypted data, which normally does not compress.
  # Option 'large_read' could improve performance.
  SSHFS_OPTIONS+=" -oauto_cache,kernel_cache,compression=no,large_read "

  # This workaround is often needed, for example by rsync.
  SSHFS_OPTIONS+=" -o workaround=rename "

  # Option 'Ciphers=arcfour' reduces encryption CPU overhead at the cost of security. But this should not matter much because
  #                          you will probably be using an encrypted filesystem on top.
  #                          Some SSH servers reject this cipher though, and all you get is an "read: Connection reset by peer" error message.

  SSHFS_OPTIONS+=" -o uid=\"$(id --user)\",gid=\"$(id --group)\" "

  local CMD_MOUNT
  printf -v CMD_MOUNT \
         "%q %s -- %q  %q" \
         "$SSHFS_TOOL" \
         "$SSHFS_OPTIONS" \
         "$REMOTE_PATH" \
         "$LOCAL_MOUNT_POINT"

  echo "$CMD_MOUNT"
  eval "$CMD_MOUNT"

  echo "In case something fails, the command to manually unmount is: $CMD_UNMOUNT"


  if $SHOULD_OPEN_AFTER_MOUNTING; then
    local CMD_OPEN_FOLDER

    if is_var_set "OPEN_FILE_EXPLORER_CMD"; then
      printf -v CMD_OPEN_FOLDER \
             "%q -- %q" \
             "$OPEN_FILE_EXPLORER_CMD" \
             "$LOCAL_MOUNT_POINT"
    else
      printf -v CMD_OPEN_FOLDER \
             "xdg-open %q" \
             "$LOCAL_MOUNT_POINT"
    fi

    echo "$CMD_OPEN_FOLDER"
    eval "$CMD_OPEN_FOLDER"
  fi
}


do_unmount ()
{
  echo "$CMD_UNMOUNT"
  eval "$CMD_UNMOUNT"
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


# ------- Entry point -------

if (( UID == 0 )); then
  # This script should not run under root from the beginning.
  abort "The user ID is zero, are you running this script as root?"
fi

declare -r CMD_LINE_ERR_MSG="Only one optional argument is allowed: 'mount' (the default), 'mount-no-open' or 'unmount' / 'umount'."

if (( $# == 0 )); then

  MODE=mount

elif (( $# == 1 )); then

  case "$1" in
    mount)         MODE=mount;;
    mount-no-open) MODE=mount-no-open;;
    unmount)       MODE=unmount;;
    umount)        MODE=unmount;;
    *) abort "Wrong argument \"$1\". $CMD_LINE_ERR_MSG";;
  esac

else
  abort "Invalid arguments. $CMD_LINE_ERR_MSG"
fi


case "$MODE" in
  mount)         do_mount true;;
  mount-no-open) do_mount false;;
  unmount)       do_unmount;;

  *) abort "Internal error: Invalid mode \"$MODE\".";;
esac
