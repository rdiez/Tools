#!/bin/bash

# Version 1.02.
#
# This is the kind of script I use to conveniently mount and unmount a gocryptfs
# encrypted filesystem. This can be used for example to encrypt files on a USB stick
# or a similar portable drive.
#
# The first time you will have to create your encrypted filesystem manually.
# Mount your USB stick and run a command like this:
#
#   gocryptfs -init -- "/some/dir/YourEncryptedDir"
#
# Then edit variables USB_DATA_PATH etc. below in this script.
#
# Optionally set environment variable OPEN_FILE_EXPLORER_CMD to control how
# to open a file explorer window on the just-mounted filesystem.
#
# Afterwards, use this script to mount and dismount it with a minimum of fuss:
#
#   mount-gocryptfs.sh
#     or
#   mount-gocryptfs.sh mount-no-open
#
# and afterwards:
#
#   mount-gocryptfs.sh umount
#     or
#   mount-gocryptfs.sh unmount
#
#
# Copyright (c) 2018-2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# This is where you system normally automounts the USB stick that contains the encrypted filesystem.
declare -r USB_DATA_PATH="/media/$USER/YourVolumeId/YourEncryptedDir"

# If you leave PASSWORD_FILE empty, gocryptfs will prompt you for the password.
# WARNING: The password file contains the password in clear text, so always keep
#          the password file inside an encrypted filesystem.
declare -r PASSWORD_FILE="$HOME/YourPasswordFile"

# This is where you want to mount the encrypted filesystem.
declare -r MOUNT_POINT="$HOME/AllYourMountDirectories/YourMountDirectory"


# --- You probably will not need to modify anything after this point ---


declare -r GOCRYPTFS_TOOL="gocryptfs"

declare -r -i EXIT_CODE_ERROR=1
declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


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


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


printf -v CMD_UNMOUNT "fusermount -u -z -- %q"  "$MOUNT_POINT"


create_mount_point_dir ()
{
  local -r L_MOUNT_POINT="$1"

  mkdir --parents -- "$L_MOUNT_POINT"

  # Normally, we would remove the execute ('x') and write ('w') permissions of the mount point directory.
  # This way, if mounting the remote filesystem fails, other processes will not inadvertently write to your local disk.
  # Unfortunately, gocryptfs uses FUSE, which requires those permissions.
  if false; then
    chmod a-wx "$L_MOUNT_POINT"
  fi
}


prepare_mount_point ()
{
  local -r L_MOUNT_POINT="$1"

  CREATED_MSG=""

  # If the mount point happens to exist as a broken symlink, it was probably left behind
  # by sibling script mount-windows-shares-gvfs.sh , so delete it.
  if [ -h "$L_MOUNT_POINT" ] && [ ! -e "$L_MOUNT_POINT" ]; then

    rm -f -- "$L_MOUNT_POINT"

    create_mount_point_dir "$L_MOUNT_POINT"
    CREATED_MSG=" (removed existing broken link, then created)"

  elif [ -e "$L_MOUNT_POINT" ]; then

    if ! [ -d "$L_MOUNT_POINT" ]; then
      abort "Mount point \"$L_MOUNT_POINT\" is not a directory."
    fi

    # This check may be unnecessary, because the gocryptfs documentation mentions that FUSE disallows
    # mounting non-empty directory by default, see gocryptfs' option '-nonempty'.
    if ! is_dir_empty "$L_MOUNT_POINT"; then
      abort "Mount point \"$L_MOUNT_POINT\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mount point."
    fi

  else

    create_mount_point_dir "$L_MOUNT_POINT"
    CREATED_MSG=" (created)"

  fi
}


do_mount ()
{
  local -r SHOULD_OPEN_AFTER_MOUNTING="$1"

  verify_tool_is_installed "$GOCRYPTFS_TOOL" "gocryptfs"

  if ! test -d "$USB_DATA_PATH"; then
    abort "Directory \"$USB_DATA_PATH\" does not exist."
  fi

  prepare_mount_point "$MOUNT_POINT"

  local PASSWORD_OPTION

  if [ -z "$PASSWORD_FILE" ]; then
    PASSWORD_OPTION=""
  else
    printf -v PASSWORD_OPTION -- \
           "-passfile %q " \
           "$PASSWORD_FILE"
  fi

  printf "Mounting \"%s\" on \"%s\"%s...\\n" "$USB_DATA_PATH" "$MOUNT_POINT" "$CREATED_MSG"

  local CMD_MOUNT
  printf -v CMD_MOUNT \
         "%q %s-- %q  %q" \
         "$GOCRYPTFS_TOOL" \
         "$PASSWORD_OPTION" \
         "$USB_DATA_PATH" \
         "$MOUNT_POINT"

  echo "$CMD_MOUNT"
  eval "$CMD_MOUNT"

  echo "In case something fails, the command to manually unmount is: $CMD_UNMOUNT"

  if $SHOULD_OPEN_AFTER_MOUNTING; then
    local CMD_OPEN_FOLDER

    if is_var_set "OPEN_FILE_EXPLORER_CMD"; then
      printf -v CMD_OPEN_FOLDER  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD"  "$MOUNT_POINT"
    else
      printf -v CMD_OPEN_FOLDER  "xdg-open %q"  "$MOUNT_POINT"
    fi

    echo
    echo "$CMD_OPEN_FOLDER"
    eval "$CMD_OPEN_FOLDER"
  fi
}


do_unmount ()
{
  echo "$CMD_UNMOUNT"
  eval "$CMD_UNMOUNT"

  # We do not need to delete the mount point directory after unmounting, but
  # removing unused mount points normally reduces unwelcome clutter.
  #
  # We should remove more than the last directory component, see option '--parents' in the 'mkdir' invocation,
  # but we do not have the flexibility in this script yet to know where to stop.
  rmdir -- "$MOUNT_POINT"
}


# ------- Entry point -------

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
