#!/bin/bash

# Version 1.01.
#
# Copyright (c) 2015-2016 R. Diez - Licensed under the GNU AGPLv3
# Please send feedback to rdiezmail-tools@yahoo.de
#
# USAGE:
#
# This is the script I used to use to 'comfortably' mount the Strato Hidrive over WebDAV on my Linux PC,
# and then mount an EncFS encrypted filesystem (or 2 of them) on top of it.
# I have not used it for a long time. I am keeping it in case I need this kind of logic again in the future.
#
# NOTE: EncFS development has stalled, abd some security concerns remain unanswered.
#       It is probably best to migrate to gocryptfs.
#
# Without any arguments, the script will mount the filesystems mentioned above.
# If you specify "umount" or "unmount" as the first (and only) command-line argument,
# it will unmount all filesystems.
#
# MOUNT METHODS:
#
# You can choose the mount method for the remote filesystem, see MOUNT_METHOD_UNENCRYPTED below.
# Implemented methods are:
# - davfs2             This method tends to hang, see further below for details.
# - gvfs-mount-webdav  This method does not actually work, see further below for details.
# - sshfs              I haven't got much experience with this method yet.
#
# PREREQUISITES:
#
# - For the 'davfs2' mount method, this script needs the WebDAV Linux File System
#   (package 'davfs2' on Ubuntu/Debian).
#
# - For the 'gvfs-mount-webdav' mount method:
#
#   - You have to install GVFS and FUSE support on your Linux OS beforehand. On Debian, the packages
#     are called "gvfs-bin", "gvfs-backends" and "gvfs-fuse". You can install them with the
#     following command:
#       sudo apt-get install gvfs-bin gvfs-backends gvfs-fuse
#
#   - Your user account must be a member of the "fuse" group. You can do that with the
#     following command:
#       sudo adduser "$USER" fuse
#
#   - For the 'sshfs' mount method, this script needs tool 'sshfs' (the package is also called 'sshfs'
#     on Ubuntu/Debian).
#
# INSTALLATION:
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
# - You will have to mount your Strato Hidrive once (turn off MOUNT_ENCRYPTED_1 and MOUNT_ENCRYPTED_2),
#   create a "Data1" directory (see ENCRYPTED_FS_PATH_1 below), and run the following
#   command (with your Strato username instead of $STRATO_USERNAME):
#     encfs "$HOME/StratoHidrive/MountpointUnencrypted/users/$STRATO_USERNAME/Data1" "$HOME/StratoHidrive/EncFs"
# - Unmount it with:
#     fusermount --unmount "$HOME/StratoHidrive/EncFs"
#
# Afterwards, this script should be able to mount the Hidrive and the EncFS filesystems on top
# with a minimum of fuss.
#
# CAVEATS AND FURTHER NOTES:
#
# For the 'davfs2' mount method:
#
#   - You need to type your root (sudo) password every time (if sudo has not cached it),
#     because this script mounts the Hidrive with 'sudo mount'.
#
#   - If you do not want to be prompted for your Strato username and password every time,
#     edit file "/etc/davfs2/secrets" as root and add a line like the following.
#     Note that your password will then be visible in plain text to anybody with root privileges.
#
#       https://your_strato_username.webdav.hidrive.strato.com/ your_strato_username your_strato_password
#
#     Alternatively, if you add option username="your_strato_username" to the mount -o flags below,
#     you will only be prompted for your Strato password (and not for your Strato username).
#     Note that your Strato username will then be visible to everyone in the output of the 'ps' command.
#
#   - I had trouble with davfs2, it often managed to hang my whole KDE session.
#     "davfs2 often freezes any program that uses it"
#     I reported the bug here:
#       https://bugs.launchpad.net/ubuntu/+source/davfs2/+bug/1538445
#     In order to alleviate the problem, I edited file /etc/davfs2/davfs2.conf as root and
#     added the following settings:
#       use_locks 0
#       gui_optimize 1
#     This work-around does not suffice, sometimes davfs2 still hangs.
#
#   - Strato HiDrive has not been very reliable in my experience. Sometimes, files land in the 'lost+found'
#     directory for no apparent reason. I am not sure yet whether this happens because of the Strato
#     servers, or because of an davfs2 issue. Therefore, this script checks whethere there are any files there
#     and opens a file explorer window on it, so that they do not remain unnoticed for a long time.
#
# For the 'gvfs-mount-webdav' mount method:
#
#   - This method does not really work, as GIO's FUSE mounts are not POSIX compatible, to the extent
#     that I expect only the most simple accesses (like copying or writing a whole file at once) to work.
#     Apparently, it is a known problem, see this discussion I started:
#       "Operation not supported" using EncFS over WebDAV gvfs-mount
#       https://mail.gnome.org/archives/gvfs-list/2016-May/msg00002.html
#     In my opinion, this is a serious issue, as users will expect the FUSE mount to work reasonably well
#     in common scenarios. I feel it is a disservice to the community that the Debian/Ubuntu package
#     'gvfs-fuse' does not mention such a shortcoming prominently (or at all).
#
#     For more GVfs trouble, unresolved for years, see:
#     - Fuse prefix is not recognized for symlinked files during GFile object creation
#       https://gitlab.gnome.org/GNOME/gvfs/-/issues/283
#     - Add operations to support O_WRONLY and O_RDWR in fuse daemon
#       https://gitlab.gnome.org/GNOME/gvfs/-/issues/249
#
#   - If you do not want to be prompted for your Strato password every time, enter your password
#     in variable STRATO_PASSWORD below. Note that your password will then be visible in plain text
#     to anybody that can read this script file.
#
#   - If you are having trouble unmounting a GVFS mount point because it is still in use,
#     command "lsof | grep ^gvfs" might help. Tool "gvfs-mount --unmount" does not seem
#     to have a "lazy unmount" option like 'umount' has.
#
#   - If you type the wrong password, tool 'gvfs-mount' will enter an infinite loop (as of Kubuntu 14.04 in Oct 2014,
#     gvfs version 1.20.1). As a result, this script will appear to hang.
#     The reason is that gvfs-mount does not realise when the stdin file descriptor reaches the end of file,
#     which is the case as this scripts redirects stdin in order to feed it with the password.
#     The only way out is to press Ctrl+C to interrupt the script together with all its child processes.
#     I reported this issue (see bug 742942 in https://bugzilla.gnome.org/) and it has been fixed for version 1.23).

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
# Mount methods are: davfs2, gvfs-mount-webdav, sshfs.
STRATO_USERNAME="your_strato_username_here"

# This password is only used for method gvfs-mount-webdav.
STRATO_PASSWORD="your_password_here"

MOUNT_METHOD_UNENCRYPTED="sshfs"
BASE_DIR="$HOME/StratoHidrive"
# Whereas the 'davfs2' method needs an existing directory as mountpoint, the 'gvfs-mount-webdav'
# method generates the mountpoint at a system-defined location.
# This script creates the following link, which is independent of the mount method.
MOUNT_LINK="$BASE_DIR/RemoteUnencrypted"
MOUNT_POINT_UNENCRYPTED="$BASE_DIR/MountpointUnencrypted"  # Only used for the 'davfs2' method.
OPEN_EXPLORER_WINDOW_ON_MOUNT_UNENCRYPTED=false

USER_SUBDIR="users/$STRATO_USERNAME"


# Encrypted filesystem 1.

MOUNT_POINT_ENCRYPTED_1="$BASE_DIR/MountpointEncrypted1"
OPEN_EXPLORER_WINDOW_ON_MOUNT_ENCRYPTED_1=true

# See comments about security further above for more information on encrypting the EncFS password.
IS_LONG_PASSWORD_ENCRYPTED_1=false

LONG_PASSWORD_FILENAME_1="$BASE_DIR/StratoHidriveEncfsLongPassword1.txt"
ENCRYPTED_FS_PATH_1="$MOUNT_LINK/$USER_SUBDIR/Data1"


# Encrypted filesystem 2.

MOUNT_POINT_ENCRYPTED_2="$BASE_DIR/MountpointEncrypted2"
OPEN_EXPLORER_WINDOW_ON_MOUNT_ENCRYPTED_2=false

# See comments about security further above for more information on encrypting the EncFS password.
IS_LONG_PASSWORD_ENCRYPTED_2=false

LONG_PASSWORD_FILENAME_2="$BASE_DIR/StratoHidriveEncfsLongPassword2.txt"
ENCRYPTED_FS_PATH_2="$MOUNT_LINK/$USER_SUBDIR/Data2"


# ---- You probably do not need to change anything below this point ----


declare -r EXIT_CODE_ERROR=1
declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1
declare -r SCRYPT_TOOL="scrypt"
declare -r ENCFS_TOOL="encfs"
declare -r SSHFS_TOOL="sshfs"
declare -r GVFS_MOUNT_TOOL="gvfs-mount"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


open_explorer_window ()
{
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


# This routine exists because sometimes I have seen "readlink -f" failing to deliver the symlink target
# without printing any error message at all. Sometimes, trying to access a just-mounted Windows share
# yields error "cannot access /run/user/1000/gvfs/smb-share:domain=blah,server=blah,share=blah,user=blah: Input/output error",
# and seemingly this causes "readlink -f" to silently fail. At least it returns a non-zero status code.
#
# It looks like readlink's flag "-f" makes it actually try to access the remote server. I have removed that flag,
# because we do not actually need the absolute, canonical path here. This way, readlink always succeed,
# even if the remote server is not accessible yet.

get_link_target ()
{
  set +o errexit

  EXISTING_LINK_TARGET="$(readlink -- "$1")"

  local EXIT_CODE="$?"

  set -o errexit

  if (( EXIT_CODE != 0 )); then
    abort "Cannot read the target for symbolic link \"$1\", readlink failed with exit code $EXIT_CODE."
  fi

  if [[ $EXISTING_LINK_TARGET = "" ]]; then
    abort "Cannot read the target for symbolic link \"$1\", readlink returned an empty string for that symlink."
  fi
}


create_or_update_symbolic_link ()
{
  local LINK_FILENAME="$1"
  local TARGET_FILENAME="$2"

  local PRINT_LINK_INFO=false

  if [ -h "$LINK_FILENAME" ]; then
    # The file exists and is a symbolic link.

    local EXISTING_LINK_TARGET
    get_link_target "$LINK_FILENAME"

    if [[ $EXISTING_LINK_TARGET == "$TARGET_FILENAME" ]]; then
      if $PRINT_LINK_INFO; then
        printf "\"%s\" -> \"%s\" (symlink already existed)\\n" "$LINK_FILENAME" "$TARGET_FILENAME"
      fi
    else
      if $PRINT_LINK_INFO; then
        printf "\"%s\" -> \"%s\" (rewriting symlink)\\n" "$LINK_FILENAME" "$TARGET_FILENAME"
      fi
      rm -- "$LINK_FILENAME"
      ln --symbolic -- "$TARGET_FILENAME" "$LINK_FILENAME"
    fi

  elif [ -e "$LINK_FILENAME" ]; then

    abort "Error creating symbolic link: File \"$LINK_FILENAME\" exists but is not a symbolic link. I am not sure whether I should delete it."

  else

    if $PRINT_LINK_INFO; then
      printf "\"%s\" -> \"%s\" (creating symlink)\\n" "$LINK_FILENAME" "$TARGET_FILENAME"
    fi
    ln --symbolic -- "$TARGET_FILENAME" "$LINK_FILENAME"

  fi
}


delete_symbolic_link ()
{
  local LINK_FILENAME="$1"

  if [ -h "$LINK_FILENAME" ]; then
    # The file exists and is a symbolic link.
    rm -- "$LINK_FILENAME"

  elif [ -e "$LINK_FILENAME" ]; then

    abort "Error deleting symbolic link: File \"$LINK_FILENAME\" exists but is not a symbolic link. I am not sure whether I should delete it."

  else

    echo "Nothing do to here." >/dev/null

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
  # This script uses variable UID as a parameter to 'mount'. Maybe we could avoid using it,
  # if 'mount' can reliably infer the UID.
  # But in any case, this script should probably not run under root anyway.
  abort "The user ID is zero, are you running this script as root?"
fi


ERR_MSG="Only one optional argument is allowed: 'mount' (the default) or 'unmount' / 'umount'."

if (( $# == 0 )); then

  SHOULD_MOUNT=true

elif (( $# == 1 )); then

  if [[ $1 = "unmount" ]]; then
    SHOULD_MOUNT=false
  elif [[ $1 = "umount" ]]; then
    SHOULD_MOUNT=false
  else
    abort "Wrong argument \"$1\". $ERR_MSG"
  fi
else
  abort "Invalid arguments. $ERR_MSG"
fi


if $SHOULD_MOUNT; then

  # Check against some common errors upfront.

  if $MOUNT_UNENCRYPTED; then

    case "$MOUNT_METHOD_UNENCRYPTED" in
      davfs2)  echo "Nothing to do here." >/dev/null;;
      sshfs)  verify_tool_is_installed "$SSHFS_TOOL" "sshfs";;
      gvfs-mount-webdav)  command -v "$GVFS_MOUNT_TOOL" >/dev/null 2>&1  ||  abort "Tool '$GVFS_MOUNT_TOOL' is not installed. You may have to install it with your Operating System's package manager.";;
      *) abort "Unsupported mount method \"$MOUNT_METHOD_UNENCRYPTED\" for unencrypted filesystem.";;
    esac
  fi

  if $MOUNT_ENCRYPTED_1 || $MOUNT_ENCRYPTED_2; then

    command -v "$ENCFS_TOOL" >/dev/null 2>&1  ||  abort "Tool '$ENCFS_TOOL' is not installed. You may have to install it with your Operating System's package manager."

    if $IS_LONG_PASSWORD_ENCRYPTED_1 || $IS_LONG_PASSWORD_ENCRYPTED_2; then
      command -v "$SCRYPT_TOOL" >/dev/null 2>&1  ||  abort "Tool '$SCRYPT_TOOL' is not installed. You may have to install it with your Operating System's package manager."
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

    case "$MOUNT_METHOD_UNENCRYPTED" in
      davfs2|sshfs)  mkdir --parents "$MOUNT_POINT_UNENCRYPTED"
                     if ! is_dir_empty "$MOUNT_POINT_UNENCRYPTED"; then
                       abort "Mount point \"$MOUNT_POINT_UNENCRYPTED\" is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mountpoint."
                     fi
                     ;;
      gvfs-mount-webdav) echo "Nothing to do here." >/dev/null;;
      *) abort "Unsupported mount method \"$MOUNT_METHOD_UNENCRYPTED\" for unencrypted filesystem.";;
    esac
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

    echo "If you wish to connect with a GIO (a GNOME VFS API) client like Nautilus, the URL is:"
    echo "  davs://$STRATO_USERNAME@$STRATO_USERNAME.webdav.hidrive.strato.com:443/$USER_SUBDIR"
    echo "This uses the same system as gvfs-mount, so you will not need to enter your WebDAV password again if you are using the 'gvfs-mount' method."
    echo "If you wish to connect with a KIO (KDE Input/Output) client like Konqueror and Dolphin, the URL is:"
    echo "  webdavs://$STRATO_USERNAME@$STRATO_USERNAME.webdav.hidrive.strato.com:443/$USER_SUBDIR"
    echo "Apparently, this is a separate system, so you will need to type your WebDAV password again."
    echo "Firefox supports WebDAV natively, the URL is:"
    echo "  https://$STRATO_USERNAME@$STRATO_USERNAME.webdav.hidrive.strato.com:443/$USER_SUBDIR"

    echo "Mounting the unencrypted remote filesystem..."

    LOCAL_UID="$(id --user)"   # Should be the same as Bash variable UID.
    LOCAL_GID="$(id --group)"  # I haven't found an equivalent Bash variable for this.

    case "$MOUNT_METHOD_UNENCRYPTED" in
      davfs2)  CMD="sudo mount -t davfs -o uid=\"$LOCAL_UID\",gid=\"$LOCAL_GID\" -- \"https://$STRATO_USERNAME.webdav.hidrive.strato.com/\" \"$MOUNT_POINT_UNENCRYPTED\""
               echo "$CMD"
               eval "$CMD"
               ;;

      sshfs)
               SSHFS_OPTIONS=""

               SSHFS_OPTIONS+=" -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 "

               # Option 'auto_cache' means "enable caching based on modification times", it can improve performance but maybe risky.
               # Option 'kernel_cache' could improve performance.
               # Option 'compression=no' improves performance if you are largely transferring encrypted data, which normally does not compress.
               # Option 'large_read' could improve performance.
               SSHFS_OPTIONS+=" -oauto_cache,kernel_cache,compression=no,large_read "

               # This workaround is often needed, for example by rsync.
               SSHFS_OPTIONS+=" -o workaround=rename"

               # Option 'Ciphers=arcfour' reduces encryption CPU overhead at the cost of security. But this should not matter much because
               #                          you will probably be using an encrypted filesystem on top.
               #                          Some SSH servers reject this cipher though, and all you get is an "read: Connection reset by peer" error message.

               SSHFS_OPTIONS+=" -o uid=\"$(id --user)\",gid=\"$(id --group)\" "

               SSHFS_OPTIONS+=" -o password_stdin"

               printf -v CMD \
                      "%q %s -- %q  %q" \
                      "$SSHFS_TOOL" \
                      "$SSHFS_OPTIONS" \
                      "$STRATO_USERNAME@shell.xShellz.com:/home/$STRATO_USERNAME" \
                      "$MOUNT_POINT_UNENCRYPTED"

               echo "$CMD"
               CMD+=" >/dev/null <<<\"$STRATO_PASSWORD\""
               eval "$CMD"
               ;;

      gvfs-mount-webdav)  CMD="\"$GVFS_MOUNT_TOOL\" -- davs://$STRATO_USERNAME@$STRATO_USERNAME.webdav.hidrive.strato.com:443"
                          echo "$CMD"
                          CMD+=" >/dev/null <<<\"$STRATO_PASSWORD\""
                          eval "$CMD"
                          ;;

      *) abort "Unsupported mount method \"$MOUNT_METHOD_UNENCRYPTED\" for unencrypted filesystem.";;
    esac


    if ! is_var_set "XDG_RUNTIME_DIR"; then
      abort "Environment variable XDG_RUNTIME_DIR is not set."
    fi

    # This is where your system creates the GVfs directory entries with the mountpoint information:
    declare -r GVFS_MOUNT_DIR="$XDG_RUNTIME_DIR/gvfs"
    # Known locations are:
    #   /run/user/$UID/gvfs   # For Ubuntu 16.04 and 18.04.
    #   /run/user/$USER/gvfs  # For Ubuntu versions 12.10, 13.04 and 13.10.
    #   $HOME/.gvfs           # For Ubuntu 12.04 and older.

    case "$MOUNT_METHOD_UNENCRYPTED" in
      davfs2|sshfs)  create_or_update_symbolic_link "$MOUNT_LINK" "$MOUNT_POINT_UNENCRYPTED";;
      gvfs-mount-webdav)
        GVFS_MOUNT_FILENAME="$GVFS_MOUNT_DIR/dav:host=$STRATO_USERNAME.webdav.hidrive.strato.com,ssl=true,user=$STRATO_USERNAME"
        if ! [ -d "$GVFS_MOUNT_FILENAME" ]; then
          abort "The GVFS mountpoint does not exist at \"$GVFS_MOUNT_FILENAME\". Check prerequisites package 'gvfs-fuse' and member of group 'fuse'."
        fi
        create_or_update_symbolic_link "$MOUNT_LINK" "$GVFS_MOUNT_FILENAME";;
      *) abort "Unsupported mount method \"$MOUNT_METHOD_UNENCRYPTED\" for unencrypted filesystem.";;
    esac

    echo "Unencrypted mountpoint location (via symbolic link):"
    echo "  $MOUNT_LINK"

    if $OPEN_EXPLORER_WINDOW_ON_MOUNT_UNENCRYPTED; then
      open_explorer_window "$MOUNT_LINK"
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
    # As an alternative to --stdinpass, option --extpass=program could be more reliable.
    CMD="\"$ENCFS_TOOL\" --stdinpass \"$ENCRYPTED_FS_PATH_1\" \"$MOUNT_POINT_ENCRYPTED_1\""
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
    # As an alternative to --stdinpass, option --extpass=program could be more reliable.
    CMD="\"$ENCFS_TOOL\" --stdinpass \"$ENCRYPTED_FS_PATH_2\" \"$MOUNT_POINT_ENCRYPTED_2\""
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

  LOST_PLUS_FOUND_DIR="$MOUNT_LINK/lost+found"
  FILES_IN_LOST_PLUS_FOUND_DIR="$(shopt -s nullglob && shopt -s dotglob && echo "$LOST_PLUS_FOUND_DIR/"*)"
  if [[ -n $FILES_IN_LOST_PLUS_FOUND_DIR ]]; then
    echo "Files detected in the lost+found directory. Opening an explorer window on it."
    open_explorer_window "$LOST_PLUS_FOUND_DIR"
  fi

else

  if $MOUNT_ENCRYPTED_2; then
    CMD_ENCRYPTED_2="fusermount --unmount \"$MOUNT_POINT_ENCRYPTED_2\""
    echo "In case you need to type it manually, the command to unmount the encrypted filesystem 2 is:"
    echo "  $CMD_ENCRYPTED_2"
  fi

  if $MOUNT_ENCRYPTED_1; then
    CMD_ENCRYPTED_1="fusermount --unmount \"$MOUNT_POINT_ENCRYPTED_1\""
    echo "In case you need to type it manually, the command to unmount the encrypted filesystem 1 is:"
    echo "  $CMD_ENCRYPTED_1"
  fi

  if $MOUNT_UNENCRYPTED; then
    case "$MOUNT_METHOD_UNENCRYPTED" in
      davfs2)  CMD_UNENCRYPTED="sudo umount \"$MOUNT_POINT_UNENCRYPTED\"";;
      sshfs) CMD_UNENCRYPTED="fusermount --unmount \"$MOUNT_POINT_UNENCRYPTED\"";;
      gvfs-mount-webdav) CMD_UNENCRYPTED="\"$GVFS_MOUNT_TOOL\" --unmount -- davs://$STRATO_USERNAME@$STRATO_USERNAME.webdav.hidrive.strato.com/";;
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

    delete_symbolic_link "$MOUNT_LINK"
  fi

  echo "Done."

fi
