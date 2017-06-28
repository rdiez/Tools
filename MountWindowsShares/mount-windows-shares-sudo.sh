#!/bin/bash

# mount-windows-shares-sudo.sh version 1.41
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3
#
# Mounting Windows shares under Linux can be a frustrating affair.
# At some point in time, I decided to write this script template
# to ease the pain.
#
# This script helps in the following scenario:
# - You need to mount a given set of Windows file shares every day.
# - You do not mind using a text console.
# - You wish to mount with the traditional Linux method (you need Linux root password).
# - You want the choice to store your Windows account passwords on this script,
#   which is convenient but not very safe, or to enter the password every time,
#   so that the system forgets it straight away.
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
# If you are having trouble unmounting a mountpoint because it is still in use,
# command "lsof" might help. Alternatively, this script could use umount's
# "lazy unmount" option, but then you should add a waiting loop with a time-out
# at the end. Otherwise, you cannot be sure whether the mountpoints have been
# unmounted or not when this script ends.
#
# You'll have to edit this script in order to add your particular Windows shares.
# However, the only thing you will probably ever need to change
# is routine user_settings() below.
#
# If 'mount' fails to mount a file system of type "cifs", your system is probably
# missing the 'mount.cifs' tool. On Ubuntu/Debian systems, the package to install
# is called 'cifs-utils'.
#
# A better alternative would be to use a graphical tool like Gigolo, which can
# automatically mount your favourite shares on start-up. Gigolo uses the FUSE-based
# mount system, which does not require the root password in order to mount Windows shares.
# Unfortunately, I could not get it to work reliably unter Ubuntu 14.04 as of May 2014.


set -o errexit
set -o nounset
set -o pipefail

user_settings ()
{
  # Specify here your Windows account details.

  WINDOWS_DOMAIN="MY_DOMAIN"  # If there is no Windows Domain, this would be the Windows computer name (hostname).
                              # Apparently, the workgroup name works too. In fact, I do not think this name
                              # matters at all if there is no domain.
  WINDOWS_USER="MY_LOGIN"

  # If you do not want to be prompted for your Windows password every time,
  # you will have to store your password in variable WINDOWS_PASSWORD below.
  # SECURITY WARNING: If you choose not to prompt for the Windows password every time,
  #                   and you store the password below, anyone that can read this script
  #                   can also find out your password.
  # Special password "prompt" means that the user will be prompted for the password.

  WINDOWS_PASSWORD="prompt"


  # Specify here the network shares to mount or unmount.
  #
  # Arguments to add_mount():
  # 1) Windows path to mount.
  # 2) Mount directory, which must be empty and will be created if it does not exist.
  # 3) Options, specify at least "rw" for 'read/write', or alternatively "ro" for 'read only'.

  add_mount "//SERVER1/ShareName1/Dir1" "$HOME/WindowsShares/Server1ShareName1Dir1" "rw"
  add_mount "//SERVER2/ShareName2/Dir2" "$HOME/WindowsShares/Server2ShareName2Dir2" "rw"


  # If you use more than one Windows account, you have to repeat everything above for each account. For example:
  #
  #  WINDOWS_DOMAIN="MY_DOMAIN_2"
  #  WINDOWS_USER="MY_LOGIN_2"
  #  WINDOWS_PASSWORD="prompt"
  #
  #  add_mount "//SERVER3/ShareName3/Dir3" "$HOME/WindowsShares/Server3ShareName3Dir3" "rw"
  #  add_mount "//SERVER4/ShareName4/Dir4" "$HOME/WindowsShares/Server4ShareName4Dir4" "rw"
}


BOOLEAN_TRUE=0
BOOLEAN_FALSE=1

SPECIAL_PROMPT_WINDOWS_PASSWORD="prompt"


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


declare -A ALL_WINDOWS_PASSWORDS=()  # Associative array.

get_windows_password ()
{
  local MOUNT_WINDOWS_DOMAIN="$1"
  local MOUNT_WINDOWS_USER="$2"
  local MOUNT_WINDOWS_PASSWORD="$3"

  if [[ $MOUNT_WINDOWS_PASSWORD != "$SPECIAL_PROMPT_WINDOWS_PASSWORD" ]]; then
    RETRIEVED_WINDOWS_PASSWORD="$MOUNT_WINDOWS_PASSWORD"
    return
  fi

  local KEY="$MOUNT_WINDOWS_DOMAIN/$MOUNT_WINDOWS_USER"

  if test "${ALL_WINDOWS_PASSWORDS[$KEY]+string_returned_ifexists}"; then
    RETRIEVED_WINDOWS_PASSWORD="${ALL_WINDOWS_PASSWORDS[$KEY]}"
    return
  fi

  read -r -s -p "Please enter the password for Windows account $MOUNT_WINDOWS_DOMAIN\\$MOUNT_WINDOWS_USER: " RETRIEVED_WINDOWS_PASSWORD
  printf "\n"

  ALL_WINDOWS_PASSWORDS["$KEY"]="$RETRIEVED_WINDOWS_PASSWORD"
}


declare -a MOUNT_ARRAY=()

declare -i MOUNT_ENTRY_ARRAY_ELEM_COUNT=6

add_mount ()
{
  if [ $# -ne 3 ]; then
    abort "Wrong number of arguments passed to add_mount()."
  fi

  # Do not allow a terminating slash. Otherwise, we'll have trouble comparing
  # the paths with the contents of /proc/mounts.

  if str_ends_with "$1" "/"; then
    abort "Windows share paths must not end with a slash (/) character. The path was: $1"
  fi

  if str_ends_with "$2" "/"; then
    abort "Mountpoints must not end with a slash (/) character. The path was: $2"
  fi

  MOUNT_ARRAY+=( "$1" "$2" "$3" "$WINDOWS_DOMAIN" "$WINDOWS_USER" "$WINDOWS_PASSWORD" )
}


mount_elem ()
{
  local MOUNT_ELEM_NUMBER="$1"
  local WINDOWS_SHARE="$2"
  local MOUNT_POINT="$3"
  local MOUNT_OPTIONS="$4"
  local MOUNT_WINDOWS_DOMAIN="$5"
  local MOUNT_WINDOWS_USER="$6"
  local MOUNT_WINDOWS_PASSWORD="$7"

  if test "${DETECTED_MOUNT_POINTS[$MOUNT_POINT]+string_returned_ifexists}"; then
    local MOUNTED_REMOTE_DIR="${DETECTED_MOUNT_POINTS[$MOUNT_POINT]}"

    if [[ $MOUNTED_REMOTE_DIR != "$WINDOWS_SHARE" ]]; then
      abort "Mountpoint \"$MOUNT_POINT\" already mounted. However, it does not reference \"$WINDOWS_SHARE\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
    fi

    printf  "%i: Already mounted \"%s\" -> \"%s\"...\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT"
  else
    CREATED_MSG=""

    if [ -e "$MOUNT_POINT" ]; then

     if ! [ -d "$MOUNT_POINT" ]; then
       abort "Mountpoint \"$MOUNT_POINT\" is not a directory."
     fi

     if ! is_dir_empty "$MOUNT_POINT"; then
       abort "Mountpoint \"$MOUNT_POINT\" is not empty. While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
     fi

    else

      mkdir --parents -- "$MOUNT_POINT"
      CREATED_MSG=" (created)"

    fi


    printf  "%i: Mounting \"%s\" -> \"%s\"%s...\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$CREATED_MSG"

    get_windows_password "$MOUNT_WINDOWS_DOMAIN" "$MOUNT_WINDOWS_USER" "$MOUNT_WINDOWS_PASSWORD"

    local CMD="mount -t cifs \"$WINDOWS_SHARE\" \"$MOUNT_POINT\" -o "
    CMD+="user=\"$MOUNT_WINDOWS_USER\""
    CMD+=",uid=\"$UID\""
    CMD+=",password=\"$RETRIEVED_WINDOWS_PASSWORD\""
    CMD+=",domain=\"$MOUNT_WINDOWS_DOMAIN\""
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
      abort "Mountpoint \"$MOUNT_POINT\" does not reference \"$WINDOWS_SHARE\" as expected, but \"$MOUNTED_REMOTE_DIR\" instead."
    fi

    printf "%i: Unmounting \"%s\"...\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE"
    sudo umount -t cifs "$MOUNT_POINT"
  else
    printf  "%i: Not mounted \"%s\".\n" "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE"
  fi
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


test_unescape_path ()
{
  unescape_path "Test\0121"  # Tests an embedded new-line character.
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test\1341"  # "Test\1"
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test\\0401"  # "Test 1"
  echo "\"$UNESCAPED_PATH\""

  unescape_path "\\040\\0401\\040\\0402\\040\\040"  # "  1  2  "
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test\\040äöüßÄÖÜñÑ\\0402"  # "Test äöüßÄÖÜñÑ 2"
  echo "\"$UNESCAPED_PATH\""

  unescape_path "Test040"  # "Test040"
  echo "\"$UNESCAPED_PATH\""
}

if false; then
  test_unescape_path
  abort "Finished testing."
fi


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
declare -i MOUNT_ENTRY_REMINDER="$(( MOUNT_ARRAY_ELEM_COUNT % MOUNT_ENTRY_ARRAY_ELEM_COUNT ))"

if [ $MOUNT_ENTRY_REMINDER -ne 0  ]; then
  abort "Invalid element count, array MOUNT_ARRAY is malformed."
fi

read_proc_mounts


# If we wanted, we could always prompt for the sudo password upfront as follows, but we may not need it after all.
#   sudo bash -c "echo \"This is just to request the root password if needed. sudo will cache it during the next minutes.\" >/dev/null"


for ((i=0; i<MOUNT_ARRAY_ELEM_COUNT; i+=MOUNT_ENTRY_ARRAY_ELEM_COUNT)); do

  MOUNT_ELEM_NUMBER="$((i/MOUNT_ENTRY_ARRAY_ELEM_COUNT+1))"
  WINDOWS_SHARE="${MOUNT_ARRAY[$i]}"
  MOUNT_POINT="${MOUNT_ARRAY[$((i+1))]}"
  MOUNT_OPTIONS="${MOUNT_ARRAY[$((i+2))]}"
  MOUNT_WINDOWS_DOMAIN="${MOUNT_ARRAY[$((i+3))]}"
  MOUNT_WINDOWS_USER="${MOUNT_ARRAY[$((i+4))]}"
  MOUNT_WINDOWS_PASSWORD="${MOUNT_ARRAY[$((i+5))]}"

  if $SHOULD_MOUNT; then
    mount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT" "$MOUNT_OPTIONS" "$MOUNT_WINDOWS_DOMAIN" "$MOUNT_WINDOWS_USER" "$MOUNT_WINDOWS_PASSWORD"
  else
    unmount_elem "$MOUNT_ELEM_NUMBER" "$WINDOWS_SHARE" "$MOUNT_POINT"
  fi

done
