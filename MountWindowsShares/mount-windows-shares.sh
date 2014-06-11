#!/bin/bash

# mount-windows-shares.sh version 1.00
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3
#
# Mounting Windows shares under Linux can be a frustrating affair.
# At some point in time, I decided to write this script template
# to ease the pain.
#
# This script helps in the following scenario:
# - You need to mount a given set of Windows file shares every day.
# - You have just one Windows account for all of them.
# - You do not mind using a text console.
# - You wish to mount with the traditional Linux method (you need the root password).
# - You do not want to store your root or Windows account password on the local
#   Linux PC. That means you want to enter the password every time, and the system
#   should forget it straight away.
# - Sometimes  mounting or unmounting a Windows share fails, for example with
#   error message "device is busy", so you need to retry.
#   This script should skip already-mounted shares, so that simply retrying
#   eventually works without further manual intervention.
# - Every now and then you add or remove a network share, but by then
#   you have already forgotten all the mount details and don't want
#   to consult the man pages again.
#
# With no arguments, this script mounts all shares it knows of. Specify parameter
# "umount" or "unmount" in order to unmount all shares.
#
# You'll have to edit this script in order to add your particular Windows shares.
# However, the only thing you will probably ever need to change
# is routine user_settings() below.
#
# A better alternative would be to use a graphical tool like Gigolo, which can
# automatically mount your favourite shares on start-up. Gigolo uses the FUSE-based
# mount system, which does not require the root password in order to mount Windows shares.
# Unfortunately, I could not get it to work reliably unter Ubuntu 14.04 as of Mai 2014.


set -o errexit
set -o nounset
set -o pipefail

user_settings ()
{
 # Specify here your Windows account details.
 WINDOWS_DOMAIN="MY_DOMAIN"
 WINDOWS_USER="MY_LOGIN"

  # Specify here the network shares to mount or unmount.
  #
  # Arguments to add_mount():
  # 1) Windows path to mount.
  # 2) Mount directory, which must be empty and will be created if it does not exist.
  # 3) Options, specify at least "rw" for 'read/write', or alternatively "ro" for 'read only'.

  add_mount "//SERVER1/Share1/Dir1" "$HOME/WindowsShares/Dir1" "rw"
  add_mount "//SERVER2/Share2/Dir2" "$HOME/WindowsShares/Dir2" "rw"
}


BOOLEAN_TRUE=0
BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  case "$1" in
     *$2) return $BOOLEAN_TRUE;;
     *)   return $BOOLEAN_FALSE;;
  esac
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.
  local -a FILES=( $1/* )

  if [ ${#FILES[@]} -eq 0 ]; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


ALREADY_ASKED_WINDOWS_PASSWORD=false

ask_windows_password ()
{
  if $ALREADY_ASKED_WINDOWS_PASSWORD; then
    return
  fi

  read -s -p "Windows password: " WINDOWS_PASSWORD
  printf "\n"

  ALREADY_ASKED_WINDOWS_PASSWORD=true
}


declare -a MOUNT_ARRAY=()

declare -i MOUNT_ENTRY_ARRAY_ELEM_COUNT=3

add_mount ()
{
  if [ $# -ne $MOUNT_ENTRY_ARRAY_ELEM_COUNT ]; then
    abort "Wrong number of arguments passed to add_mount()."
  fi

  # Do not allow a terminating slash. Otherwise, we'll have trouble comparing
  # the paths with the contents of /proc/mounts.

  if str_ends_with "$1" "/"; then
    abort "Windows share paths must not end with a slash (/) character. The path was: $1"
  fi

  if str_ends_with "$2" "/"; then
    abort "Mount points must not end with a slash (/) character. The path was: $2"
  fi

  MOUNT_ARRAY+=( "$1" "$2" "$3" )
}


mount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SHARE="$2"
  local MOUNT_POINT="$3"
  local MOUNT_OPTIONS="$4"

  if test "${DETECTED_MOUNT_POINTS[$MOUNT_POINT]+string_returned_ifexists}"; then
    local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$MOUNT_POINT]}"

    if [[ $MOUNTED_REMOTE_DIR != "$WINDOWS_SHARE" ]]; then
      abort "Mount point \"$MOUNT_POINT\" already mounted. However, it does not reference \"$WINDOWS_SHARE\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
    fi

    printf  "%i: Already mounted \"%s\" -> \"%s\"...\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT"
  else
    CREATED_MSG=""

    if [ -e "$MOUNT_POINT" ]; then

     if ! [ -d "$MOUNT_POINT" ]; then
       abort "Mount point \"$MOUNT_POINT\" is not a directory."
     fi

     if ! is_dir_empty "$MOUNT_POINT"; then
       abort "Mount point \"$MOUNT_POINT\" is not empty. While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
     fi
     
    else

      mkdir --parents -- "$MOUNT_POINT"
      CREATED_MSG=" (created)"

    fi


    printf  "%i: Mounting \"%s\" -> \"%s\"%s...\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$CREATED_MSG"

    ask_windows_password

    local CMD="mount -t cifs \"$WINDOWS_SHARE\" \"$MOUNT_POINT\" -o "
    CMD+="user=\"$WINDOWS_USER\""
    CMD+=",uid=\"$UID\""
    CMD+=",password=\"$WINDOWS_PASSWORD\""
    CMD+=",domain=\"$WINDOWS_DOMAIN\""
    CMD+=",$MOUNT_OPTIONS"

    eval "sudo $CMD"
  fi
}


unmount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SHARE="$2"
  local MOUNT_POINT="$3"

  if test "${DETECTED_MOUNT_POINTS[$MOUNT_POINT]+string_returned_ifexists}"; then
    local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$MOUNT_POINT]}"

    if [[ $MOUNTED_REMOTE_DIR != "$WINDOWS_SHARE" ]]; then
      abort "Mount point \"$MOUNT_POINT\" does not reference \"$WINDOWS_SHARE\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
    fi

    printf "%i: Unmounting \"%s\"...\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE"
    sudo umount -t cifs "$MOUNT_POINT"
  else
    printf  "%i: Not mounted \"%s\".\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE"
  fi
}


declare -A  DETECTED_MOUNT_POINTS  # Associative array.

read_proc_mounts ()
{
  # Read the whole /proc/swaps file at once.
  local PROC_MOUNTS_FILENAME="/proc/mounts"
  local PROC_MOUNTS_CONTENTS="$(<$PROC_MOUNTS_FILENAME)"

  # Split on newline characters.
  # Bash 4 has 'readarray', or we have used something like [ IFS=$'\n' read -rd '' -a PROC_MOUNTS_LINES <<<"$PROC_MOUNTS_CONTENTS" ] instead.
  local PROC_MOUNTS_LINES
  IFS=$'\n' PROC_MOUNTS_LINES=($PROC_MOUNTS_CONTENTS)

  local PROC_MOUNTS_LINE_COUNT="${#PROC_MOUNTS_LINES[@]}"

  local LINE
  local PARTS
  local REMOTE_DIR
  local MOUNT_POINT

  for ((i=0; i<$PROC_MOUNTS_LINE_COUNT; i+=1)); do
    LINE="${PROC_MOUNTS_LINES[$i]}"

    IFS=$' \t' PARTS=($LINE)

    REMOTE_DIR="${PARTS[0]}"
    MOUNT_POINT="${PARTS[1]}"

    DETECTED_MOUNT_POINTS["$MOUNT_POINT"]="$REMOTE_DIR"

  done
}


# ------- Entry point -------

if [ $UID -eq 0 ]
then
  # This script uses variable UID as a parameter to 'mount'. Maybe we could avoid using it,
  # if 'mount' can reliably infer the UID.
  abort "The user ID is zero, are you running this script as root?"
fi


if [ $# -eq 0 ]; then

  SHOULD_MOUNT=true

elif [ $# -eq 1 ]; then

  if [[ $1 = "unmount" ]]; then
    SHOULD_MOUNT=false
  elif [[ $1 = "umount" ]]; then
    SHOULD_MOUNT=false
  else
    abort "Wrong argument \"$1\", only optional argument \"unmount\" (or \"umount\") is valid."
  fi
else
  abort "Invalid arguments, only one optional argument \"unmount\" (or \"umount\") is valid."
fi


user_settings


declare -i MOUNT_ARRAY_ELEM_COUNT="${#MOUNT_ARRAY[@]}"
declare -i MOUNT_ENTRY_COUNT="$(( MOUNT_ARRAY_ELEM_COUNT / MOUNT_ENTRY_ARRAY_ELEM_COUNT ))"
declare -i MOUNT_ENTRY_REMINDER="$(( MOUNT_ARRAY_ELEM_COUNT % MOUNT_ENTRY_ARRAY_ELEM_COUNT ))"

if [ $MOUNT_ENTRY_REMINDER -ne 0  ]; then
  abort "Invalid element count, array MOUNT_ARRAY is malformed."
fi

read_proc_mounts


# If we wanted, we could always ask the sudo password upfront as follows, but we may not need it after all.
#   sudo bash -c "echo \"This is just to request the root password if needed. sudo will cache it during the next minutes.\" >/dev/null"


for ((i=0; i<$MOUNT_ARRAY_ELEM_COUNT; i+=$MOUNT_ENTRY_ARRAY_ELEM_COUNT)); do

  MOUNT_ELEM_NUMBER="$((i/MOUNT_ENTRY_ARRAY_ELEM_COUNT+1))"
  WINDOWS_SHARE="${MOUNT_ARRAY[$i]}"
  MOUNT_POINT="${MOUNT_ARRAY[$((i+1))]}"
  MOUNT_OPTIONS="${MOUNT_ARRAY[$((i+2))]}"

  if $SHOULD_MOUNT; then
    mount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$MOUNT_OPTIONS"
  else
    unmount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT"
  fi

done
