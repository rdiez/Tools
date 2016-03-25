#!/bin/bash

# Copyright (c) 2015-2016 R. Diez - Licensed under the GNU AGPLv3
# Please send feedback to rdiezmail-tools@yahoo.de
#
# This is the script I use to 'comfortably' mount the Strato Hidrive over WebDAV on my Linux PC,
# and then mount an EncFS encrypted filesystem (or 2 of them) on top of it.
#
# If you specify "umount" or "unmount" as the first (and only) command-line argument,
# it will unmount all filesystems.
#
# This script needs the WebDAV Linux File System (package 'davfs2' on Ubuntu/Debian).
# If you haven't disabled the local password encryption, it also needs tool 'scrypt' (package 'scrypt').
# I had trouble with davfs2, it often managed to hang my whole KDE session. In order
# to alleviate the problem, I edited file /etc/davfs2/davfs2.conf as root and
# added the following settings:
#   use_locks 0
#   gui_optimize 1
#
# In order to use this script, you will have to edit STRATO_USERNAME and so on below in order
# to match your system configuration.
#
# Before you run this script for the very first time, you will also have to manually create the
# encrypted EncFS filesystem on the Hidrive. I have chosen to give it a complex password,
# and encrypt that complex password locally with a short password.
# This way, the files on the remote server are encrypted with the complex password,
# but the password you type locally can be easier to remember.
# Warning: I am no security or encryption expert.
#
# If your local filesystem is already encrypted, you may not need to encrypt the password locally,
# which saves typing the password every time. See variable IS_LONG_PASSWORD_ENCRYPTED
# to disable the local password encryption.
#
# The steps to create an encrypted filesystem with option IS_LONG_PASSWORD_ENCRYPTED enabled are:
# - Write your long password to a temporary file. The name could be something like
#   /tmp/My-$UID.tmp , where $UID is your user ID, in order to avoid collisions with other users.
#   Make sure that you do not add an end-of-line after the password, just in case.
#   Having to create a file is unfortunate, but I could not find a way to make 'scrypt'
#   take the password from stdin.
# - Run this command (the filename must mach variable LONG_PASSWORD_FILENAME below):
#     scrypt enc /tmp/My-$UID.tmp >"$HOME/StratoHidrive/StratoHidriveEncfsLongPassword1.txt"
# - Don't forget to delete file /tmp/My-$UID.tmp afterwards.
# - You will have to manually mount your Strato Hidrive once (without this script),
#   create a "Data1" directory (see ENCRYPTED_FS_PATH_1 below), and run the following
#   command (with your Strato username instead of $STRATO_USERNAME):
#     encfs "$HOME/StratoHidrive/MountpointUnencrypted/users/$STRATO_USERNAME/Data1" "$HOME/StratoHidrive/EncFs"
# - Unmount it with:
#     fusermount -u "$HOME/StratoHidrive/EncFs"
#
# Afterwards, this script should be able to mount the Hidrive and the EncFS filesystem on top
# with a minimum of fuss. You still need to type your root (sudo) password though, because
# it mounts the Hidrive with 'sudo mount'. I hope one day I will finally manage
# to get gvfs-mount to work, so that you do not need the root password anymore.
#
# If you do not want to be prompted for your Strato username and password every time,
# edit file "/etc/davfs2/secrets" as root and add a line like the following.
# Note that your password will then be visible in plain text to anybody with root privileges.
#
#   https://your_strato_username.webdav.hidrive.strato.com/ your_strato_username your_strato_password
#
# Alternatively, if you add option username="your_strato_username" to the mount -o flags below,
# you will only be prompted for your Strato password (and not for your Strato username).
# Note that your Strato username will then be visible to everyone in the output of the 'ps' command.
#
# Strato HiDrive has not been very reliable in my experience. Sometimes, files land in the 'lost+found'
# directory for no apparent reason. Therefore, this script checks whethere there are any files there
# and opens a file explorer window on it, so that they do not remain unnoticed for a long time.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


# Normally, you need to mount your Strato Hidrive first (the 'unencrypted' data),
# and afterwards you mount the encrypted EncFS filesystem on top.
# For development and test purposes, you can enable or disable these steps here independently.
MOUNT_UNENCRYPTED=true
MOUNT_ENCRYPTED_1=true
MOUNT_ENCRYPTED_2=false

# Unencrypted data.
MOUNT_METHOD_UNENCRYPTED="webdav"
STRATO_USERNAME="your_strato_username_here"
BASE_DIR="$HOME/StratoHidrive"
MOUNT_POINT_UNENCRYPTED="$BASE_DIR/MountpointUnencrypted"
OPEN_EXPLORER_WINDOW_ON_MOUNT_UNENCRYPTED=false


# Encrypted filesystem 1.

MOUNT_POINT_ENCRYPTED_1="$BASE_DIR/MountpointEncrypted1"
OPEN_EXPLORER_WINDOW_ON_MOUNT_ENCRYPTED_1=true

# See comments about security further above for more information on encrypting the EncFS password.
IS_LONG_PASSWORD_ENCRYPTED_1=false

LONG_PASSWORD_FILENAME_1="$BASE_DIR/StratoHidriveEncfsLongPassword1.txt"
ENCRYPTED_FS_PATH_1="$MOUNT_POINT_UNENCRYPTED/users/$STRATO_USERNAME/Data1"


# Encrypted filesystem 2.

MOUNT_POINT_ENCRYPTED_2="$BASE_DIR/MountpointEncrypted2"
OPEN_EXPLORER_WINDOW_ON_MOUNT_ENCRYPTED_2=false

# See comments about security further above for more information on encrypting the EncFS password.
IS_LONG_PASSWORD_ENCRYPTED_2=false

LONG_PASSWORD_FILENAME_2="$BASE_DIR/StratoHidriveEncfsLongPassword2.txt"
ENCRYPTED_FS_PATH_2="$MOUNT_POINT_UNENCRYPTED/users/$STRATO_USERNAME/Data2"


# ---- You probably do not need to change anything below this point ----


EXIT_CODE_ERROR=1
BOOLEAN_TRUE=0
BOOLEAN_FALSE=1
SCRYPT_TOOL="scrypt"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


open_explorer_window ()
{
  # Set below the file explorer of your choice. xdg-open should work everywhere. Alternatives are:
  #
  #   nautilus --no-desktop --browser "$1" &
  #   dolphin "$1" &
  xdg-open "$1"
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.
  local -a FILES=( "$1"/* )

  if [ ${#FILES[@]} -eq 0 ]; then
    return $BOOLEAN_TRUE
  else
    if false; then
      echo "Files found: ${FILES[@]}"
    fi
    return $BOOLEAN_FALSE
  fi
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


if $SHOULD_MOUNT; then

  # Check against some common errors upfront.

  if $MOUNT_ENCRYPTED_1 || $MOUNT_ENCRYPTED_2; then

    if $IS_LONG_PASSWORD_ENCRYPTED_1 || $IS_LONG_PASSWORD_ENCRYPTED_2; then
      if [ ! "$(command -v "$SCRYPT_TOOL")" >/dev/null 2>&1 ]; then
        abort "Tool '$SCRYPT_TOOL' is not installed. You may have to install it with your Operating System's package manager."
      fi
    fi

    if $IS_LONG_PASSWORD_ENCRYPTED_1; then
      if ! test -r "$LONG_PASSWORD_FILENAME_1"; then
        abort "Cannot read password file \"$LONG_PASSWORD_FILENAME_1\"."
      fi
    fi

    if $IS_LONG_PASSWORD_ENCRYPTED_2; then
      if ! test -r "$LONG_PASSWORD_FILENAME_2"; then
        abort "Cannot read password file \"$LONG_PASSWORD_FILENAME_2\"."
      fi
    fi

  fi


  # Create the mountpoint directories if not already there.

  if $MOUNT_UNENCRYPTED; then

    mkdir --parents "$MOUNT_POINT_UNENCRYPTED"

    if ! is_dir_empty "$MOUNT_POINT_UNENCRYPTED"; then
      abort "Mount point \"$MOUNT_POINT_UNENCRYPTED\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
    fi
  fi

  if $MOUNT_ENCRYPTED_1; then

    mkdir --parents "$MOUNT_POINT_ENCRYPTED_1"

    if ! is_dir_empty "$MOUNT_POINT_ENCRYPTED_1"; then
      abort "Mount point \"$MOUNT_POINT_ENCRYPTED_1\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
    fi

  fi

  if $MOUNT_ENCRYPTED_2; then

    mkdir --parents "$MOUNT_POINT_ENCRYPTED_2"

    if ! is_dir_empty "$MOUNT_POINT_ENCRYPTED_2"; then
      abort "Mount point \"$MOUNT_POINT_ENCRYPTED_2\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
    fi

  fi


  # I am confused about the user ID and group ID of files and directories in the Strato Hidrive.
  #
  # If you mount without any uid or gid options, files and directories appear as owned by user ID 0/root and group ID 0/root.
  # You then need to be root in order to create any new files, or write to existing ones. Run "stat filename" to see this information.
  #
  # If you specify the uid option below, files appear as owned by your $UID/$USER. Therefore, it seems that Strato Hidrive does not really
  # store user IDs, at least when accessed over WebDAV from Linux.
  #
  # However, the behaviour with groups and directories is different. Without the gid option below, files appear as owned by group ID of 0/root.
  # With gid, files appear with group ID of $UID/$USER.
  # This works because there normally is a local Linux group with the same name as your $USER and with the same ID as your $UID.
  # If that does not hold true on your system, it may not work properly.
  #
  # Directories behave differently with gid. Existing directories continue to appear as owned by group ID 0/root,
  # but new ones appear with $UID/$USER. Therefore, the owner group information seems to be persisted for directories.

  if $MOUNT_UNENCRYPTED; then

    echo "Mounting the Strato Hidrive..."

    case "$MOUNT_METHOD_UNENCRYPTED" in
      webdav)  CMD="sudo mount -t davfs -o uid=\"$UID\",gid=\"$UID\" -- \"https://$STRATO_USERNAME.webdav.hidrive.strato.com/\" \"$MOUNT_POINT_UNENCRYPTED\"";;
      *) abort "Unsupported mount method \"$MOUNT_METHOD_UNENCRYPTED\" for unencrypted filesystem.";;
    esac

    echo "$CMD"
    eval "$CMD"

    if $OPEN_EXPLORER_WINDOW_ON_MOUNT_UNENCRYPTED; then
      open_explorer_window "$MOUNT_POINT_UNENCRYPTED"
    fi

  fi

  if $MOUNT_ENCRYPTED_1; then

    echo "Mounting the encrypted filesystem 1..."

    # Filesystem and mountpoint must exist, otherwise encfs will prompt the user, breaking this script.
    # We have created the mountpoint above if it did not exist, but check again nevertheless that it is a directory.

    if ! test -d "$ENCRYPTED_FS_PATH_1"; then
      abort "Directory \"$ENCRYPTED_FS_PATH_1\" does not exist."
    fi

    if ! test -d "$MOUNT_POINT_ENCRYPTED_1"; then
      abort "Directory \"$MOUNT_POINT_ENCRYPTED_1\" does not exist."
    fi

    if $IS_LONG_PASSWORD_ENCRYPTED_1; then
      # I am using scrypt for "key stretching" (more information in Wikipedia). There are
      # of course alternatives, look for "PBKDF2" for more information.
      echo "Please enter the short password to decrypt the long password for encrypted filesystem 1 below."
      LONG_PASSWORD_1="$("$SCRYPT_TOOL" dec "$LONG_PASSWORD_FILENAME_1")"
    else
      LONG_PASSWORD_1="$(<"$LONG_PASSWORD_FILENAME_1")"
    fi

    # I have not been able to add the <<< bit to the CMD string.
    CMD="encfs --stdinpass \"$ENCRYPTED_FS_PATH_1\" \"$MOUNT_POINT_ENCRYPTED_1\""
    echo "$CMD"
    eval "$CMD" <<<"$LONG_PASSWORD_1"

    # Forget the password as soon as possible.
    LONG_PASSWORD_1=""

    echo "Encrypted mountpoint location:"
    echo "  $MOUNT_POINT_ENCRYPTED_1"

    if $OPEN_EXPLORER_WINDOW_ON_MOUNT_ENCRYPTED_1; then
      open_explorer_window "$MOUNT_POINT_ENCRYPTED_1"
    fi

  fi

  if $MOUNT_ENCRYPTED_2; then

    echo "Mounting the encrypted filesystem 2..."

    # Filesystem and mountpoint must exist, otherwise encfs will prompt the user, breaking this script.
    # We have created the mountpoint above if it did not exist, but check again nevertheless that it is a directory.

    if ! test -d "$ENCRYPTED_FS_PATH_2"; then
      abort "Directory \"$ENCRYPTED_FS_PATH_2\" does not exist."
    fi

    if ! test -d "$MOUNT_POINT_ENCRYPTED_2"; then
      abort "Directory \"$MOUNT_POINT_ENCRYPTED_2\" does not exist."
    fi

    if $IS_LONG_PASSWORD_ENCRYPTED_2; then
      # I am using scrypt for "key stretching" (more information in Wikipedia). There are
      # of course alternatives, look for "PBKDF2" for more information.
      echo "Please enter the short password to decrypt the long password for encrypted filesystem 2 below."
      LONG_PASSWORD_2="$("$SCRYPT_TOOL" dec "$LONG_PASSWORD_FILENAME_2")"
    else
      LONG_PASSWORD_2="$(<"$LONG_PASSWORD_FILENAME_2")"
    fi

    # I have not been able to add the <<< bit to the CMD string.
    CMD="encfs --stdinpass \"$ENCRYPTED_FS_PATH_2\" \"$MOUNT_POINT_ENCRYPTED_2\""
    echo "$CMD"
    eval "$CMD" <<<"$LONG_PASSWORD_2"

    # Forget the password as soon as possible.
    LONG_PASSWORD_2=""

    echo "Encrypted mountpoint location:"
    echo "  $MOUNT_POINT_ENCRYPTED_2"

    if $OPEN_EXPLORER_WINDOW_ON_MOUNT_ENCRYPTED_2; then
      open_explorer_window "$MOUNT_POINT_ENCRYPTED_2"
    fi

  fi

  LOST_PLUS_FOUND_DIR="$MOUNT_POINT_UNENCRYPTED/lost+found"
  FILES_IN_LOST_PLUS_FOUND_DIR="$(shopt -s nullglob && shopt -s dotglob && echo $LOST_PLUS_FOUND_DIR/*)"
  if [[ ! -z $FILES_IN_LOST_PLUS_FOUND_DIR ]]; then
    echo "Files detected in the lost+found directory. Opening an explorer window on it."
    open_explorer_window "$LOST_PLUS_FOUND_DIR"
  fi

else

  if $MOUNT_ENCRYPTED_2; then
    CMD_ENCRYPTED_2="fusermount -u \"$MOUNT_POINT_ENCRYPTED_2\""
    echo "In case you need to type it manually, the command to unmount the encrypted filesystem 2 is:"
    echo "  $CMD_ENCRYPTED_2"
  fi

  if $MOUNT_ENCRYPTED_1; then
    CMD_ENCRYPTED_1="fusermount -u \"$MOUNT_POINT_ENCRYPTED_1\""
    echo "In case you need to type it manually, the command to unmount the encrypted filesystem 1 is:"
    echo "  $CMD_ENCRYPTED_1"
  fi

  if $MOUNT_UNENCRYPTED; then
    case "$MOUNT_METHOD_UNENCRYPTED" in
      webdav)
        CMD_UNENCRYPTED="sudo umount \"$MOUNT_POINT_UNENCRYPTED\"";;
      *) abort "Unsupported mount method \"$MOUNT_METHOD_UNENCRYPTED\" for unencrypted filesystem.";;
    esac

    echo "In case you need to type it manually, the command to unmount the unencrypted filesystem is:"
    echo "  $CMD_UNENCRYPTED"
  fi

  if $MOUNT_ENCRYPTED_2; then
    echo "Unmounting the encrypted filesystem 2..."
    echo "$CMD_ENCRYPTED_2"
    eval "$CMD_ENCRYPTED_2"
  fi

  if $MOUNT_ENCRYPTED_1; then
    echo "Unmounting the encrypted filesystem 1..."
    echo "$CMD_ENCRYPTED_1"
    eval "$CMD_ENCRYPTED_1"
  fi

  if $MOUNT_UNENCRYPTED; then
    echo "Unmounting the Strato Hidrive..."
    echo "$CMD_UNENCRYPTED"
    eval "$CMD_UNENCRYPTED"
  fi

  echo "Done."

fi
