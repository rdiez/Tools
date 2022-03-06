#!/bin/bash

# Version 1.02.
#
# This script template mounts one filesystem, and then another one on top of it.
# For example, mount first with SSHFS for basic file services, and then
# with gocryptfs for data encryption.
# If mounting the second filesystem fails, it unmounts the first one automatically.
#
# You need to prepare separate scripts to mount the first and the second filesystem
# by using the other scripts provided in this directory.
#
# Instead of using this script directly, you will find it more convenient to use simple wrappers
# like mount-my-stacked-filesystems.sh . This way, all wrappers share the same mounting and unmounting logic.
#
# Optionally set environment variable OPEN_FILE_EXPLORER_CMD to control how
# to open a file explorer window on the just-mounted filesystem.
#
# Usage to mount and unmount:
#
#   mount-my-stacked-filesystems.sh
#     or
#   mount-my-stacked-filesystems.sh mount-no-open
#
# and afterwards:
#
#   mount-my-stacked-filesystems.sh umount
#     or
#   mount-my-stacked-filesystems.sh unmount
#
#
# Copyright (c) 2020-2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


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

CMD_LINE_ERR_MSG="Invalid command-line arguments."
CMD_LINE_ERR_MSG+=$'\n'
CMD_LINE_ERR_MSG+="Usage: $0 <mount script 1> <mount script 2> ['mount' (the default), 'mount-no-open' or 'unmount' / 'umount']"
CMD_LINE_ERR_MSG+=$'\n'
CMD_LINE_ERR_MSG+="See the comments at the beginning of this script for more information."

if (( $# == 2 )); then

  MODE=mount

elif (( $# == 3 )); then

  case "$3" in
    mount)         MODE=mount;;
    mount-no-open) MODE=mount-no-open;;
    unmount)       MODE=unmount;;
    umount)        MODE=unmount;;
    *) abort "Wrong argument \"$3\". $CMD_LINE_ERR_MSG";;
  esac

else
  abort "Invalid arguments. $CMD_LINE_ERR_MSG"
fi

declare -r MOUNT_SCRIPT_1="$1"
declare -r MOUNT_SCRIPT_2="$2"


printf -v UNMOUNT_1_CMD \
       "%q unmount" \
       "$MOUNT_SCRIPT_1"


case "$MODE" in
  mount)         do_mount true;;
  mount-no-open) do_mount false;;
  unmount)       do_unmount;;

  *) abort "Internal error: Invalid mode \"$MODE\".";;
esac
