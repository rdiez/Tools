#!/bin/bash

# Version 1.01.
#
# This script template mounts one filesystem, and then another one on top of it.
# For example, mount first with SSHFS for basic file services, and then
# with gocryptfs for data encryption.
# If mounting the second filesystem fails, it unmounts the first one automatically.
#
# You need to prepare separate scripts to mount the first and the second filesystem
# using the other script templates provided in this directory. And then
# you need to edit the MOUNT_SCRIPT_x variables below.
#
# Optionally set environment variable OPEN_FILE_EXPLORER_CMD to control how
# to open a file explorer window on the just-mounted filesystem.
#
# Usage to mount and unmount:
#
#   mount-stacked.sh
#     or
#   mount-stacked.sh mount-no-open
#
# and afterwards:
#
#   mount-stacked.sh umount
#     or
#   mount-stacked.sh unmount
#
#
# Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r MOUNT_SCRIPT_1="MySingleMountScripts/mount-sshfs.sh"
declare -r MOUNT_SCRIPT_2="MySingleMountScripts/mount-gocryptfs.sh"


# --- You probably will not need to modify anything after this point ---


declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


do_mount ()
{
  local -r SHOULD_OPEN_AFTER_MOUNTING="$1"

  local CMD

  printf -v CMD \
         "%q mount-no-open" \
         "$MOUNT_SCRIPT_1"

  echo "Mounting the first filesystem..."

  echo "$CMD"
  eval "$CMD"


  local MOUNT_ARG

  if $SHOULD_OPEN_AFTER_MOUNTING; then
    MOUNT_ARG="mount"
  else
    MOUNT_ARG="mount-no-open"
  fi

  printf -v CMD \
         "%q %s" \
         "$MOUNT_SCRIPT_2" \
         "$MOUNT_ARG"

  echo
  echo "Mounting the second filesystem..."

  echo "$CMD"

  set +o errexit

  eval "$CMD"

  local EXIT_CODE="$?"

  set -o errexit

  if (( EXIT_CODE != 0 )); then
    echo
    echo "Mounting the second filesystem failed with exit code $EXIT_CODE. Automatically unmounting the first one..."
    echo "$UNMOUNT_1_CMD"
    eval "$UNMOUNT_1_CMD"
    echo "The first filesystem has been unmounted."
    echo
    echo "Mounting the second filesystem failed with exit code $EXIT_CODE."
    echo "The first filesystem has been unmounted automatically."
    exit "$EXIT_CODE_ERROR"
  fi

  echo
  echo "Finished mounting both filesystems."
}


do_unmount ()
{
  local CMD

  printf -v CMD \
         "%q unmount" \
         "$MOUNT_SCRIPT_2"

  echo "$CMD"
  eval "$CMD"

  echo

  echo "$UNMOUNT_1_CMD"
  eval "$UNMOUNT_1_CMD"
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


printf -v UNMOUNT_1_CMD \
       "%q unmount" \
       "$MOUNT_SCRIPT_1"


case "$MODE" in
  mount)         do_mount true;;
  mount-no-open) do_mount false;;
  unmount)       do_unmount;;

  *) abort "Internal error: Invalid mode \"$MODE\".";;
esac
