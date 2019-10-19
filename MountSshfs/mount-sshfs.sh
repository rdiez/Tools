#!/bin/bash

# Version 1.01.
#
# This is the kind of script I use to conveniently mount and unmount an SSHFS
# filesystem on a remote host.
#
# You will need to edit variables REMOTE_PATH etc. below in this script.
#
# Afterwards, use this script to mount and dismount the hard-coded path with a minimum of fuss:
#
#   mount-sshfs.sh
#
#   mount-sshfs.sh umount
#
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r REMOTE_PATH="MyFriendlySshHostName:/home/some/path"
declare -r LOCAL_MOUNT_POINT="$HOME/MountPoints/some/path"

declare -r EXIT_CODE_ERROR=1
declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1


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


printf -v CMD_UNMOUNT "fusermount -u -z -- %q"  "$LOCAL_MOUNT_POINT"


do_mount ()
{
  local -r SHOULD_OPEN_AFTER_MOUNTING="$1"

  mkdir --parents -- "$LOCAL_MOUNT_POINT"

  if ! is_dir_empty "$LOCAL_MOUNT_POINT"; then
    abort "Mount point \"$LOCAL_MOUNT_POINT\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
  fi

  local SSHFS_OPTIONS=""
  SSHFS_OPTIONS+=" -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 "
  SSHFS_OPTIONS+=" -oauto_cache,kernel_cache,compression=no,large_read "
  SSHFS_OPTIONS+=" -o uid=\"$(id --user)\",gid=\"$(id --group)\" "

  local CMD_MOUNT
  printf -v CMD_MOUNT "sshfs %s -- %q  %q"  "$SSHFS_OPTIONS"  "$REMOTE_PATH"  "$LOCAL_MOUNT_POINT"

  echo "$CMD_MOUNT"
  eval "$CMD_MOUNT"

  echo "In case something fails, the command to manually unmount is: $CMD_UNMOUNT"


  if $SHOULD_OPEN_AFTER_MOUNTING; then
    local CMD_OPEN_FOLDER

    if is_var_set "OPEN_FILE_EXPLORER_CMD"; then
      printf -v CMD_OPEN_FOLDER  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD"  "$LOCAL_MOUNT_POINT"
    else
      printf -v CMD_OPEN_FOLDER  "xdg-open %q"  "$LOCAL_MOUNT_POINT"
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


# ------- Entry point -------

ERR_MSG="Only one optional argument is allowed: 'mount' (the default), 'mount-no-open' or 'unmount' / 'umount'."

if (( $# == 0 )); then

  MODE=mount

elif (( $# == 1 )); then

  case "$1" in
    mount)         MODE=mount;;
    mount-no-open) MODE=mount-no-open;;
    unmount)       MODE=unmount;;
    umount)        MODE=unmount;;
    *) abort "Wrong argument \"$1\". $ERR_MSG";;
  esac

else
  abort "Invalid arguments. $ERR_MSG"
fi


case "$MODE" in
  mount)         do_mount true;;
  mount-no-open) do_mount false;;
  unmount)       do_unmount;;

  *) abort "Internal error: Invalid mode \"$MODE\".";;
esac
