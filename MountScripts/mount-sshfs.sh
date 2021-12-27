#!/bin/bash

# Version 1.06.
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
# Copyright (c) 2019-2021 R. Diez - Licensed under the GNU AGPLv3

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


# According to the Linux kernel 3.16 documentation, /proc/mounts uses the same format as fstab,
# which should only escape spaces in the mountpoint (the second field, fs_file).
# However, another source in the Internet listed the following escaped characters:
# - space (\040)
# - tab (\011)
# - newline (\012)
# - backslash (\134)
# That makes sense, so I guess the fstab documentation is wrong.
# Note that command 'umount' works with the first field (fs_spec) in /etc/mtab, but it takes spaces
# instead of the escape sequence \040.
#
# The kernel documentation does not mention the fact either that the first field (fs_spec)
# gets escaped too, at least for CIFS (Windows shares) mountpoints.
#
# This routine unescapes all octal numeric values with the form "\" + 3 octal digits, not just the ones
# listed above. It is not clear from the fstab documentation how escaping sequences are generated.

unescape_path()
{
  local STILL_TO_PROCESS="$1"
  local RESULT=""

  # It is not easy to parse strings in bash. There is no "non-greedy" support for regular expressions.
  # You cannot replace several matches with the result of a function call on the matched text.
  # Going character-by-character is very slow in a shell script.
  # Bash can unescape a similar format with printf "%b", but it does not exactly match our escaping specification.

  local REGULAR_EXPRESSION="\\\\([0-7][0-7][0-7])(.*)"
  local UNESCAPED_CHAR
  local -i LEN_BEFORE_MATCH

  while [[ $STILL_TO_PROCESS =~ $REGULAR_EXPRESSION ]]; do
    if false; then
      echo "Matched: \"${BASH_REMATCH[1]}\", \"${BASH_REMATCH[2]}\""
    fi

    LEN_BEFORE_MATCH=$(( ${#STILL_TO_PROCESS} - 4 - ${#BASH_REMATCH[2]}))
    RESULT+="${STILL_TO_PROCESS:0:LEN_BEFORE_MATCH}"
    printf -v UNESCAPED_CHAR "%b" "\\0${BASH_REMATCH[1]}"
    RESULT+="$UNESCAPED_CHAR"
    STILL_TO_PROCESS=${BASH_REMATCH[2]}
  done

  RESULT+="$STILL_TO_PROCESS"

  UNESCAPED_PATH="$RESULT"
}


declare -A  DETECTED_MOUNT_POINTS  # Associative array.

read_proc_mounts ()
{
  # We are reading /proc/mounts because it is maintained by the kernel and has the most accurate information.
  # An alternative would be reading /etc/mtab, but that is maintained in user space by 'mount' and
  # may become out of sync.

  # Read the whole /proc/swaps file at once.
  local PROC_MOUNTS_FILENAME="/proc/mounts"
  local PROC_MOUNTS_CONTENTS
  PROC_MOUNTS_CONTENTS="$(<$PROC_MOUNTS_FILENAME)"

  # Split on newline characters.
  local PROC_MOUNTS_LINES
  mapfile -t PROC_MOUNTS_LINES <<< "$PROC_MOUNTS_CONTENTS"

  local PROC_MOUNTS_LINE_COUNT="${#PROC_MOUNTS_LINES[@]}"

  local LINE
  local PARTS
  local REMOTE_DIR
  local MOUNT_POINT

  for ((i=0; i<PROC_MOUNTS_LINE_COUNT; i+=1)); do
    LINE="${PROC_MOUNTS_LINES[$i]}"

    IFS=$' \t' read -r -a PARTS <<< "$LINE"

    REMOTE_DIR_ESCAPED="${PARTS[0]}"
    MOUNT_POINT_ESCAPED="${PARTS[1]}"

    unescape_path "$REMOTE_DIR_ESCAPED"
    REMOTE_DIR="$UNESCAPED_PATH"

    unescape_path "$MOUNT_POINT_ESCAPED"
    MOUNT_POINT="$UNESCAPED_PATH"

    DETECTED_MOUNT_POINTS["$MOUNT_POINT"]="$REMOTE_DIR"

  done

  if false; then
    echo "Contents of DETECTED_MOUNT_POINTS:"
    for key in "${!DETECTED_MOUNT_POINTS[@]}"; do
      printf -- "- %s=%s\\n" "$key" "${DETECTED_MOUNT_POINTS[$key]}"
    done
  fi
}


printf -v CMD_UNMOUNT \
       "fusermount -u -z -- %q" \
       "$LOCAL_MOUNT_POINT"


do_mount ()
{
  local -r SHOULD_OPEN_AFTER_MOUNTING="$1"

  if test "${DETECTED_MOUNT_POINTS[$LOCAL_MOUNT_POINT]+string_returned_ifexists}"; then

    local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$LOCAL_MOUNT_POINT]}"

    if [[ $MOUNTED_REMOTE_DIR != "$REMOTE_PATH" ]]; then
      abort "Mountpoint \"$LOCAL_MOUNT_POINT\" already mounted. However, it does not reference \"$REMOTE_PATH\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
    fi

    printf "Already mounted \"%s\" on \"%s\".\\n" "$REMOTE_PATH" "$LOCAL_MOUNT_POINT"

  else

    mkdir --parents -- "$LOCAL_MOUNT_POINT"

    if ! is_dir_empty "$LOCAL_MOUNT_POINT"; then
      abort "Mount point \"$LOCAL_MOUNT_POINT\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
    fi

    verify_tool_is_installed "$SSHFS_TOOL" "sshfs"

    local SSHFS_OPTIONS=""

    # Note that option 'reconnect' will not work with password authentication, or if the SSH key
    # is password protected and you are not using an SSH agent.
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

    # One option I still have to investigate is 'transform_symlinks', which converts absolute links on the remote machine
    # to relative, since the root directory is different when mounted with SSHFS.

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

    printf "Mounted \"%s\" on \"%s\".\\n" "$REMOTE_PATH" "$LOCAL_MOUNT_POINT"

    # This hint should not be necessary. After all, this script can unmount too,
    # and there is only one mountpoint to worry about.
    if false; then
      echo "In case something fails, the command to manually unmount is: $CMD_UNMOUNT"
    fi

  fi

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
  if test "${DETECTED_MOUNT_POINTS[$LOCAL_MOUNT_POINT]+string_returned_ifexists}"; then

    local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$LOCAL_MOUNT_POINT]}"

    if [[ $MOUNTED_REMOTE_DIR != "$REMOTE_PATH" ]]; then
      abort "Mountpoint \"$LOCAL_MOUNT_POINT\" does not reference \"$REMOTE_PATH\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
    fi

    echo "$CMD_UNMOUNT"
    eval "$CMD_UNMOUNT"

  else
    printf "Remote path \"%s\" is not mounted.\\n" "$REMOTE_PATH"
  fi
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

read_proc_mounts


case "$MODE" in
  mount)         do_mount true;;
  mount-no-open) do_mount false;;
  unmount)       do_unmount;;

  *) abort "Internal error: Invalid mode \"$MODE\".";;
esac
