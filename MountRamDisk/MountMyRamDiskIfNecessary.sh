#!/bin/bash

# Version 1.02.
#
# This script creates and mounts a RAM disk (tmpfs) at a fixed location, if not already mounted.
# The mount point location, maximum size, etc. are hard-coded in this script.
#
# A RAM disk can dramatically speed-up certain operations, such as building software with many small files.
# Just make sure that you have enough RAM, so that you do not end up hitting the swap file,
# which would defeat the whole purpose.
#
# This script uses sentinel files in order to know whether the RAM disk has already been mounted or not.
# An improvement would be to parse /proc/mounts instead of using sentinel files.
#
# It is recommended that the mount point directory is read only. For example:
#   chmod a-w "$HOME/MyRamDisk"
# This way, if mounting the RAM disk fails, other processes will not inadvertently write to your local disk.
#
# CAVEATS:
#
# - Root privileges needed.
#   Unfortunately, there seems to be no alternative RAM disks available for FUSE,
#   so your account must have root privileges for the tmpfs mount command.
#   If you do not want to enter your password each time, this script prints out the line
#   you would need to add to /etc/sudoers (always edit it with "sudo visudo"),
#   or even better, to some new file inside /etc/sudoers.d .
#
# - tmpfs is not secure if the system has a swap file that resides on a non-encrypted disk.
#
# - This script is not safe if concurrently called. If 2 processes call this script at the same time,
#   you may end up with 2 mounted tmpfs filesystems at the same mount point.
#
# Copyright (c) 2018-2026 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


escape_for_sudoers ()
{
  local STR="$1"

  # Escaping of some characters only works separately.
  STR="${STR//\\/\\\\}"  # \ -> \\
  STR="${STR//\*/\\*}"   # * -> \*
  STR="${STR//\?/\\?}"   # ? -> \?

  local CHARACTERS_TO_ESCAPE=",:=[]!"

  local -i CHARACTERS_TO_ESCAPE_LEN="${#CHARACTERS_TO_ESCAPE}"
  local -i INDEX

  for (( INDEX = 0 ; INDEX < CHARACTERS_TO_ESCAPE_LEN ; ++INDEX )); do

    local CHAR="${CHARACTERS_TO_ESCAPE:$INDEX:1}"

    STR="${STR//$CHAR/\\$CHAR}"

  done

  ESCAPED_STR="$STR"
}


generate_sudoers_lines ()
{
  local MOUNT_ARGS="$1"
  local UNMOUNT_ARGS="$2"

  echo "If you do not want to be prompted for the password each time, add these lines to some file inside \"/etc/sudoers.d\":"

  local MOUNT_CMD_FULL_PATH

  set +o errexit

  MOUNT_CMD_FULL_PATH="$(type -p "$MOUNT_CMD")"

  local TYPE_EXIT_CODE_MOUNT="$?"

  set -o errexit

  if [ $TYPE_EXIT_CODE_MOUNT -ne 0 ]; then
    abort "Command \"$MOUNT_CMD\" not found."
  fi

  local ESCAPED_STR  # This is for 2 calls to escape_for_sudoers below.

  escape_for_sudoers "$MOUNT_ARGS"

  echo "$USER ALL=(root) NOPASSWD: $MOUNT_CMD_FULL_PATH $ESCAPED_STR"


  local UNMOUNT_CMD_FULL_PATH

  set +o errexit

  UNMOUNT_CMD_FULL_PATH="$(type -p "$UNMOUNT_CMD")"

  local TYPE_EXIT_CODE_UNMOUNT="$?"

  set -o errexit

  if [ $TYPE_EXIT_CODE_UNMOUNT -ne 0 ]; then
    abort "Command \"$UNMOUNT_CMD\" not found."
  fi

  escape_for_sudoers "$UNMOUNT_ARGS"

  echo "$USER ALL=(root) NOPASSWD: $UNMOUNT_CMD_FULL_PATH $ESCAPED_STR"
}


get_filenames_in_dir ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.

  pushd "$1" >/dev/null

  FILENAMES_IN_DIR=( * )

  popd >/dev/null
}


# ------- Entry point -------

if (( $# != 0 )); then
  abort "This script takes no command-line arguments. All parameters are hard-coded in its source code."
fi


declare -r MOUNT_POINT="$HOME/MyRamDisk"

declare -r SENTINEL_FILENAME_MOUNTED="SentinelFileWhenMounted.txt"
declare -r SENTINEL_FILENAME_UNMOUNTED="SentinelFileWhenUnmounted.txt"

declare -r SENTINEL_FULL_PATH_MOUNTED="$MOUNT_POINT/$SENTINEL_FILENAME_MOUNTED"
declare -r SENTINEL_FULL_PATH_UNMOUNTED="$MOUNT_POINT/$SENTINEL_FILENAME_UNMOUNTED"

declare -r MOUNT_CMD="mount"
declare -r UNMOUNT_CMD="umount"


if ! test -d "$MOUNT_POINT"; then
  declare -r LF=$'\n'
  ERR_MSG="Mount point \"$MOUNT_POINT\" does not exist."
  ERR_MSG+="${LF}"
  ERR_MSG+="You can create it like this:"
  ERR_MSG+="${LF}"
  ERR_MSG+="  mkdir -- ${MOUNT_POINT@Q}"
  ERR_MSG+="${LF}"
  ERR_MSG+="  touch -- ${SENTINEL_FULL_PATH_UNMOUNTED@Q}"
  ERR_MSG+="${LF}"
  ERR_MSG+="  chmod a-w -- ${MOUNT_POINT@Q}"
  abort "$ERR_MSG"
fi

if [ -e "$SENTINEL_FULL_PATH_MOUNTED" ]; then
  IS_MOUNTED=true
else
  IS_MOUNTED=false
fi

if [ -e "$SENTINEL_FULL_PATH_UNMOUNTED" ]; then
  IS_UNMOUNTED=true
else
  IS_UNMOUNTED=false
fi

if $IS_MOUNTED && $IS_UNMOUNTED; then
  abort "Both sentinel files \"$SENTINEL_FILENAME_MOUNTED\" and \"$SENTINEL_FILENAME_UNMOUNTED\" exist in mount point \"$MOUNT_POINT\". You need to manually clean up this state."
fi

printf -v UNMOUNT_ARGS  "%q"  "$MOUNT_POINT"

declare -r UNMOUNT_CMD_WITH_ARGS="sudo umount $UNMOUNT_ARGS"

if $IS_MOUNTED; then
  echo "The RAM disk is already mounted."
  echo "In order to unmount it (and lose all its contents), use the following command:"
  echo "  $UNMOUNT_CMD_WITH_ARGS"
  exit 0
fi


if ! $IS_UNMOUNTED; then
  abort "Sentinel file \"$SENTINEL_FILENAME_UNMOUNTED\" does not exist in mount point \"$MOUNT_POINT\". Please create a file with that name before using this script."
fi


# Check that the mount point contains no files other than the sentinel.
#
# If you forget to call this script before using the RAM disk, you may inadvertently end up placing many files
# in your normal disk, where the mount point directory resides. The next time around, if you correctly mount
# the RAM disk beforehand, those files will be hidden under the mount. This check helps you realise that
# you have such "orphan" files under the mount point, giving you a chance to delete them and save space
# on your normal disk.

get_filenames_in_dir "$MOUNT_POINT"

case "${#FILENAMES_IN_DIR[@]}" in
 0) abort "Internal error: The mount point \"$MOUNT_POINT\" has no files.";;
 1) if [[ ${FILENAMES_IN_DIR[0]} != "$SENTINEL_FILENAME_UNMOUNTED" ]]; then
      abort "Internal error: The filename found in the mount point is not \"$SENTINEL_FILENAME_UNMOUNTED\", but \"${FILENAMES_IN_DIR[0]}\"."
    fi;;
 *) abort "The mount point \"$MOUNT_POINT\" has unexpected files. Please make sure that it only contains the sentinel file \"$SENTINEL_FILENAME_UNMOUNTED\".";;
esac


echo "The RAM disk is not mounted, so I will be creating and mounting it."

MY_UID="$(id --user)"   # Should be the same as Bash variable UID.
MY_GID="$(id --group)"  # I haven't found an equivalent Bash variable for this.

printf  -v MOUNT_ARGS -- "-t tmpfs -o nosuid,size=3G,rw,noatime,nodev,mode=700,uid=%q,gid=%q  tmpfs  %q"  "$MY_UID"  "$MY_GID"  "$MOUNT_POINT"

if true; then

  echo
  generate_sudoers_lines "$MOUNT_ARGS" "$UNMOUNT_ARGS"
  echo

fi


# I usually run this script during automated builds, where stdin is not available.
# Unfortunately, sudo does not output an error message if reading the password fails,
# so we have to manually print one on failure.

echo "Mounting..."

CMD="sudo -- $MOUNT_CMD  $MOUNT_ARGS"
echo "$CMD"

set +o errexit

eval "$CMD"

SUDO_EXIT_CODE="$?"

set -o errexit

if (( SUDO_EXIT_CODE != 0 )); then
  echo "sudo failed."
  exit "$SUDO_EXIT_CODE"
fi

echo "">"$SENTINEL_FULL_PATH_MOUNTED"

echo
echo "The RAM disk was successfully created and mounted."
echo "In order to unmount it (and lose all its contents), use the following command:"
echo "  $UNMOUNT_CMD_WITH_ARGS"
