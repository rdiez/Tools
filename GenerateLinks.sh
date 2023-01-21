#!/bin/bash

# This script places symbolic links to the most-used scripts into the specified directory
# (which is normally your personally 'Tools' or 'Utils' directory in the PATH).
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
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


create_link ()
{
  local SCRIPT="$DIR_WHERE_THIS_SCRIPT_IS/$1/$2"

  local SYMLINK_NAME="$TARGET_DIR_ABS/$2"

  if ! [ -x "$SCRIPT" ]; then
    abort "Script \"$SCRIPT\" not found or not marked as executable."
  fi

  if [ -e "$SYMLINK_NAME" ] && ! [ -h "$SYMLINK_NAME" ]; then
    abort "File \"$SYMLINK_NAME\" exists and is not a symbolic link."
  fi

  printf -v CMD  "ln --symbolic --force -- %q  %q"  "$SCRIPT"  "$SYMLINK_NAME"
  echo "$CMD"
  eval "$CMD"
}


# -------- Entry point --------

if [ $# -ne 1 ]; then
  abort "You need to pass a single argument with the target directory."
fi

TARGET_DIR="$1"

TARGET_DIR_ABS="$(readlink --canonicalize-existing --verbose -- "$TARGET_DIR")"

find_where_this_script_is

create_link "BackupFiles" "packpass.sh"
create_link "Background" "background.sh"
create_link "PipeToClipboard" "pipe-to-clipboard.sh"
create_link "PipeToClipboard" "path-to-clipboard.sh"
create_link "CopyWithRsync" "copy-with-rsync.sh"
create_link "CopyWithRsync" "move-with-rsync.sh"
create_link "DesktopNotification" "DesktopNotification.sh"
create_link "FindUsbSerialPort" "FindUsbSerialPort.sh"
create_link "Git" "clean-git-repo.sh"
create_link "Git" "git-revert-file-permissions.sh"
create_link "Git" "pull.sh"
create_link "Git" "git-stash-only-staged-changes.sh"
create_link "Git" "git-stash-only-unstaged-changes.sh"
create_link "MountScripts" "mount-sshfs.sh"
create_link "MountScripts" "mount-gocryptfs.sh"
create_link "MountScripts" "mount-stacked.sh"
create_link "DiskUsage" "diskusage.sh"
create_link "PipeToEmacs" "pipe-to-emacs-server.sh"
create_link "PrintArgumentsWrapper" "print-arguments-wrapper.sh"
create_link "TakeOwnership" "takeownership.sh"
create_link "StartDetached" "StartDetached.sh"
create_link "xsudo" "xsudo.sh"
create_link "UpdateWithApt" "update-with-apt.sh"
create_link "RunInNewConsole" "run-in-new-console.sh"
create_link "RunInNewConsole" "open-serial-port-in-new-console.sh"
create_link "NoPassword" "nopassword-polkit.sh"
create_link "NoPassword" "nopassword-sudo.sh"
create_link "OfficeSoftwareAutomation" "copy-to-old-versions-archive.sh"
create_link "Unpack" "unpack.sh"
create_link "FilterTerminalOutputForLogFile" "FilterTerminalOutputForLogFile.pl"
create_link "CountdownTimer" "CountdownTimer.pl"
create_link "AnnotateWithTimestamps" "AnnotateWithTimestamps.pl"
create_link "ImageTools" "TransformImage.sh"
create_link "RunAndWaitForAllChildren" "RunAndWaitForAllChildren.pl"
create_link "PlainTextLinter" "ptlint.pl"
create_link "OpenFileExplorer" "open-file-explorer.sh"
create_link "CreateTempDir" "create-temp-dir.sh"
