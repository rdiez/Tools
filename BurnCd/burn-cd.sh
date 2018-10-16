#!/bin/bash

# CD burning script, version 2.01.
#
# You would normally use an application like Brasero to burn CD-ROMs (or DVD-ROMs, etc).
# But sometimes you need to automate the process, so that it is faster or more reliable.
#
# I found CD burning hard to automate. I hope that this script helps.
#
# Usage:
#
#  ./burn-cd.sh  "Volume label"  "/dir/with/cd/contents"
#
# The steps that the script performs are:
#
# - Build a temporary ISO image with the files in the specified directory.
#
# - Optionally mount the ISO image for manual testing purposes,
#   so that you can see how the CD will look like.
#   You need to edit this script manually in order to enable this step, see below.
#
# - Burn the CD and eject it.
#   By ejecting we make sure that the system is not caching the data in any way.
#
# - Delete the temporary ISO image.
#
# - Close the CD tray and mount the CD.
#
# - Verify the files on the CD by comparing them with the original files (with "diff --recursive").
#
# - Eject the CD once again.
#
# The ISO image filename and the mountpoints used are always the same. They are created
# where this script resides. This should not be an issue, as you can normally burn just
# one CD at a time. This way, if something fails, you known what ISO image file to delete
# and what mountpoint to unmount. Using a temporary file under /tmp for the ISO image could
# leave one such big file behind for every failed run.
#
# Mounting the CD requires sudo privileges. Alternatively, you could enter those commands
# in the system's /etc/sudoers file (always edit that file with 'visudo'). The mount commands
# should not change because the mountpoints used are always the same.
#
# Finding your CD drive:
#
#   The first thing to do before using this script is to find out where your CD burner is located.
#
#   If your drive is at the default location /dev/cdrom , then you do not need to do anything else.
#   Otherwise, you have to find where it is.
#
#   You would normally find this out with "wodim --devices" or "wodim -scanbus", but this fails
#   often in may Linux systems, even though adding a "dev=/dev/xxx" parameter with the right
#   device name does work. To top it all, the device location is usually not clearly displayed anywhere.
#
#   As a work-around, try with any of these commands:
#
#     wodim -v -inq    # print device identification and version information
#     wodim -v -prcap  # like -inq plus detailed capability information
#     wodim -v -checkdrive  # like -inq plus it queries the "driver flags" and "supported modes".
#
#   Normally, CD drives get block device filenames like /dev/sr0, /dev/sr1 and so on. One of them is the default,
#   and is referenced from a few standard filenames with symbolic links like this:
#
#     /dev/cdrom -> /dev/sr0
#     /dev/cdrw  -> /dev/sr0
#     /dev/dvd   -> /dev/sr0
#     /dev/dvdrw -> /dev/sr0
#
#   These devices also tend to get additional character device filenames like /dev/sg0 (sg0 is the first SCSI device).
#
#   Once you have found out which block device name is the right one, set environment variable
#   BURN_CD_SH_DEV_NAME before running this script.
#
#   You would normally set that environment variable in your .bashrc file (or similar) for maximum convenience,
#   because the drive location does not change across reboots.
#   For example: export BURN_CD_SH_DEV_NAME=/dev/my_block_device
#
# Lowering your CD burning speed:
#
#   Some CD burners do not work reliably at the maximum speed (which is the default one).
#   Consider lowering the write speed. The best way is to set environment variable
#   CDR_SPEED, which wodim will honour. You would normally set that environment variable
#   in your .bashrc file (or similar) for maximum convenience.
#
#   For example, my 48x drive writes by default at 22x to 44x, depending on the CD position,
#   on average at 29x. With "export CDR_SPEED=4", it lowers the burning speed to 16x,
#   which is the minimum actually supported by this drive.
#
#   In order to find out what speeds your drive supports, issue a "wodim -v -prcap" command,
#   or look at /proc/sys/dev/cdrom/info .
#   If wodim reports the following:
#
#     Number of supported write speeds: 0
#
#   insert a blank CD and try again. This time it should report the supported burning speeds.
#
# Automounter interference:
#
#   If wodim complains like this a few times and then gives up:
#
#     Error trying to open /dev/cdrom exclusively (Device or resource busy)... retrying in 1 second.
#
#   it probably means that your system's automounter has automatically mounted the CD
#   before wodim tried to lock it.
#   Use your desktop environment's file manager to unmount the CD before trying again.
#   In order to prevent this problem, you can disable your system's automounter. Alternatively,
#   do not close the drive tray when you place a blank CD on it, as wodim will automatically
#   close the tray before starting the CD burn process.
#
# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


find_where_this_script_is ()
{
  # In this routine, command 'local' is often in a separate line, in order to prevent
  # masking any error from the external command inkoved.

  if ! is_var_set BASH_SOURCE; then
    # This happens when feeding the script to bash over an stdin redirection.
    abort "Cannot find out in which directory this script resides: built-in variable BASH_SOURCE is not set."
  fi

  local SOURCE="${BASH_SOURCE[0]}"

  local TRACE=false

  while [ -h "$SOURCE" ]; do  # Resolve $SOURCE until the file is no longer a symlink.
    TARGET="$(readlink --verbose -- "$SOURCE")"
    if [[ $SOURCE == /* ]]; then
      if $TRACE; then
        echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
      fi
      SOURCE="$TARGET"
    else
      local DIR1
      DIR1="$( dirname "$SOURCE" )"
      if $TRACE; then
        echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIR1')"
      fi
      SOURCE="$DIR1/$TARGET"  # If $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located.
    fi
  done

  if $TRACE; then
    echo "SOURCE is '$SOURCE'"
  fi

  local DIR2
  DIR2="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  if $TRACE; then
    local RDIR
    RDIR="$( dirname "$SOURCE" )"
    if [ "$DIR2" != "$RDIR" ]; then
      echo "DIR2 '$RDIR' resolves to '$DIR2'"
    fi
  fi

  DIR_WHERE_THIS_SCRIPT_IS="$DIR2"
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


validate_volume_name ()
{
  # The volume name has space for 32 characters, but Microsoft Windows recognises only 16 characters.
  # As per the ISO-9660 standard, the volume label should be maximum of 16 characters and the only allowed characters are A to Z,
  # 0 to 9, underscore and dot. I am not sure whether spaces are allowed, but they seem to work here.

  local VOLUME_NAME="$1"

  if (( ${#VOLUME_NAME} > 16 )); then
    abort "The volume name is more than 16 characters long."
  fi


  # Avoid collation issues by listing all characters individually, instead of using ranges.
  # Otherwise, Bash would include international characters like ä when matching "a-z".
  # See "shopt globasciiranges" for more information.
  local ASCII_LETTERS_UPPERCASE="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local ASCII_LETTERS_LOWERCASE="abcdefghijklmnopqrstuvwxyz"
  local ASCII_NUMBERS="0123456789"

  local REGEXP="^[$ASCII_NUMBERS$ASCII_LETTERS_UPPERCASE$ASCII_LETTERS_LOWERCASE _.]*\$"

  if ! [[ $VOLUME_NAME =~ $REGEXP ]]; then
    abort "Invalid characters in the volume name. Only ASCII characters A to Z, 0 to 9, spaces, underscores and periods are allowed."
  fi
}


if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. Specify <volume name> and <directory to burn>."
fi

VOLUME_NAME="$1"
DATA_DIR="$2"

validate_volume_name "$VOLUME_NAME"

if ! [ -d "$DATA_DIR" ]; then
  echo "The specified path is not a directory."
fi


find_where_this_script_is


declare -r BURN_CD_SH_DEV_NAME_ENV_VAR_NAME="BURN_CD_SH_DEV_NAME"

declare -r DEVNAME="${!BURN_CD_SH_DEV_NAME_ENV_VAR_NAME:-/dev/cdrom}"


# Create an ISO Image.

ISO_IMAGE_FILENAME="$DIR_WHERE_THIS_SCRIPT_IS/CdromImage.iso"

if true; then

  if is_dir_empty "$DATA_DIR"; then
    abort "There are no files under \"$DATA_DIR\". This is unusal."
  fi

  echo
  echo "Generating ISO image in file \"$ISO_IMAGE_FILENAME\"..."

  # We probably do not need to delete any existing image beforehand,
  # but do it just in case.
  if [ -f "$ISO_IMAGE_FILENAME" ]; then
    rm -- "$ISO_IMAGE_FILENAME"
  fi

  # -r : long file names work for Unix (using Rock Ridge)
  # -J : long file names work for Windows (using Joliet extensions)

  printf -v CMD  "genisoimage -r  -J  -V %q  -o %q   %q"  "$VOLUME_NAME"  "$ISO_IMAGE_FILENAME"  "$DATA_DIR"
  echo "$CMD"
  eval "$CMD"

  echo "Finished generating ISO image in file \"$ISO_IMAGE_FILENAME\"."

fi


# Enable the code below in order to mount the ISO image for manual test purposes.

if false; then

  MOUNT_POINT_ISO_IMAGE="$DIR_WHERE_THIS_SCRIPT_IS/MountPointIsoImage"

  echo "Mounting the ISO image..."

  mkdir -p -- "$MOUNT_POINT_ISO_IMAGE"

  if ! is_dir_empty "$MOUNT_POINT_ISO_IMAGE"; then
    abort "Mountpoint \"$MOUNT_POINT_ISO_IMAGE\" is not empty. While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint. Did you forget to unmount a previous ISO image?"
  fi

  printf -v CMD  "sudo mount -o ro,loop  %q  %q"  "$ISO_IMAGE_FILENAME"  "$MOUNT_POINT_ISO_IMAGE"
  echo "$CMD"
  eval "$CMD"

  sudo losetup --all

  printf -v CMD  "sudo umount %q"  "$MOUNT_POINT_ISO_IMAGE"

  echo
  echo "After you have finished inspecting the files, unmount with command: $CMD"
  echo "You can also unmount loop devices with your desktop environment's file manager."
  echo "Unmounting the ISO image should also release the loopback device automatically."

  CMD="sudo losetup --detach /dev/loopX"
  echo "If the automounter interferes, you can manually remove the loop device with: $CMD"
  echo "Consult the log above for the loop device number to use."
  echo "Do not forget to delete the ISO image file \"$ISO_IMAGE_FILENAME\"."

  exit $EXIT_CODE_SUCCESS

fi


# Burn the image.

if true; then

  # -v : display progress (increase verbosity)
  # Some people use -sao for the SAO (Session At Once) mode, which is usually called Disk At Once mode.

  printf -v CMD  "wodim  dev=%q  -v  -data  -eject  gracetime=2"  "$DEVNAME"

  # Enable this to do a "dry run" for test purposes. It does not actually burn the CD then.
  # But you still need a blank CD on the drive. Of course, the verification step
  # will then fail.
  if false; then
    CMD+="  -dummy"
  fi

  printf -v CMD  "%s -- %q"  "$CMD"  "$ISO_IMAGE_FILENAME"

  echo
  echo "Burning disk..."

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  BURN_EXIT_CODE="$?"
  set -o errexit

  if [ $BURN_EXIT_CODE -ne 0 ]; then
    echo "Burning the disk failed with exit code $BURN_EXIT_CODE."
    exit $EXIT_CODE_ERROR
  fi

  echo "Disk burnt successfully."

fi


# Enable a pause here for script development purposes.
if false; then
  echo
  read -r -p "Press Enter to continue."
fi


rm --verbose -- "$ISO_IMAGE_FILENAME"


# Verify the CD contents.

MOUNT_POINT_CDROM="$DIR_WHERE_THIS_SCRIPT_IS/MountPointCdrom"

if true; then

  # Close the CD tray again.
  echo
  echo "Closing the drive tray..."
  printf -v CMD  "eject -t %q"  "$DEVNAME"
  echo "$CMD"
  eval "$CMD"
  echo "Pause after closing the drive tray..."
  sleep 5
  echo

  echo "Verifying the files..."

  if ! is_dir_empty "$MOUNT_POINT_CDROM"; then
    abort "Mountpoint \"$MOUNT_POINT_CDROM\" is not empty. While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint. Did you forget to unmount a previous CD?"
  fi

  mkdir -p -- "$MOUNT_POINT_CDROM"

  printf -v UNMOUNT_CMD  "sudo umount --lazy %q"  "$MOUNT_POINT_CDROM"
  echo "In case this script gets abruptly interrupted, manually unmount with: $UNMOUNT_CMD"

  printf -v CMD  "sudo mount  -o ro  -t iso9660  %q %q"  "$DEVNAME"  "$MOUNT_POINT_CDROM"
  echo "$CMD"
  eval "$CMD"

  printf -v CMD  "diff --brief  --recursive  %q  %q"  "$DATA_DIR"  "$MOUNT_POINT_CDROM"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  DIFF_EXIT_CODE="$?"
  set -o errexit

  echo
  echo "Unmounting the CD..."
  echo "$UNMOUNT_CMD"
  eval "$UNMOUNT_CMD"

  echo

  if [ $DIFF_EXIT_CODE -eq 0 ]; then
    echo "Verify successful."
  else
    echo "Error verifying the data."
  fi

  echo
  echo "Pause before ejecting..."
  sleep 3

  eject "$DEVNAME"

  echo

  if [ $DIFF_EXIT_CODE -ne 0 ]; then
    echo "Verifying the data failed with exit code $DIFF_EXIT_CODE."
    exit $EXIT_CODE_ERROR
  fi

  echo "Verification successful. The CD was burnt correctly."

fi
