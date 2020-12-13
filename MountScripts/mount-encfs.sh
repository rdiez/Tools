#!/bin/bash

# Version 1.05.
#
# This is the kind of script I use to conveniently mount and unmount an EncFS
# encrypted filesystem. This can be used for example to encrypt files on a USB stick
# or a similar portable drive.
#
# NOTE: EncFS development has stalled, and some security concerns remain unanswered.
#       It is probably best to migrate to gocryptfs.
#
# WARNING: This script contains a password in clear text, so always keep it
#          inside an encrypted filesystem. Do not copy this script to an unencrypted drive
#          with the clear-text password inside!
#
# The first time you will have to create your encrypted filesystem manually.
# Mount your USB stick and run a command like this:
#
#     encfs "/media/$USER/YourVolumeId/YourEncryptedDir" "$HOME/AllYourMountDirectories/YourMountDirectory"
#
# Unmount it with:
#
#     fusermount --unmount "$HOME/AllYourMountDirectories/YourMountDirectory"
#
# Then edit variables USB_DATA_PATH etc. below in this script.
#
# Optionally set environment variable OPEN_FILE_EXPLORER_CMD to control how
# to open a file explorer window on the just-mounted filesystem.
#
# Afterwards, use this script to mount and dismount it with a minimum of fuss:
#
#   mount-encfs.sh
#     or
#   mount-encfs.sh mount-no-open
#
# and afterwards:
#
#   mount-encfs.sh umount
#     or
#   mount-encfs.sh unmount
#
#
# Copyright (c) 2018-2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# This is where you system normally automounts the USB stick.
declare -r USB_DATA_PATH="/media/$USER/YourVolumeId/YourEncryptedDir"

declare -r ENC_FS_PASSWORD="YourComplexPassword"

# This is where you want to mount the encrypted filesystem.
declare -r ENC_FS_MOUNTPOINT="$HOME/AllYourMountDirectories/YourMountDirectory"

declare -r ENCFS_TOOL="encfs"

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


printf -v CMD_UNMOUNT "fusermount -u -z -- %q"  "$ENC_FS_MOUNTPOINT"


do_mount ()
{
  local -r SHOULD_OPEN_AFTER_MOUNTING="$1"

  if ! test -d "$USB_DATA_PATH"; then
    abort "Directory \"$USB_DATA_PATH\" does not exist."
  fi

  mkdir --parents -- "$ENC_FS_MOUNTPOINT"

  if ! is_dir_empty "$ENC_FS_MOUNTPOINT"; then
    abort "Mount point \"$ENC_FS_MOUNTPOINT\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
  fi

  local CMD_MOUNT
  printf -v CMD_MOUNT "%q --stdinpass  -- %q  %q"  "$ENCFS_TOOL"  "$USB_DATA_PATH"  "$ENC_FS_MOUNTPOINT"

  echo "$CMD_MOUNT"
  eval "$CMD_MOUNT" <<<"$ENC_FS_PASSWORD"

  echo "In case something fails, the command to manually unmount is: $CMD_UNMOUNT"

  if $SHOULD_OPEN_AFTER_MOUNTING; then
    local CMD_OPEN_FOLDER

    if is_var_set "OPEN_FILE_EXPLORER_CMD"; then
      printf -v CMD_OPEN_FOLDER  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD"  "$ENC_FS_MOUNTPOINT"
    else
      printf -v CMD_OPEN_FOLDER  "xdg-open %q"  "$ENC_FS_MOUNTPOINT"
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
