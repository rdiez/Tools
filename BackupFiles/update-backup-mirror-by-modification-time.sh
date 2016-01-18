#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME="update-backup-mirror-by-modification-time.sh"
VERSION_NUMBER="1.00"

# Implemented methods are: rsync, rdiff-backup
BACKUP_METHOD="rdiff-backup"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "For backup purposes, sometimes you just want to copy all files across"
  echo "to another disk at regular intervals. There is often no need for"
  echo "encryption or compression. However, you normally don't want to copy"
  echo "all files every time around, but only those which have changed."
  echo
  echo "Assuming that you can trust your filesystem's timestamps, this script can"
  echo "get you started in little time. You can easily switch between"
  echo "rdiff-backup and rsync (see this script's source code), until you are"
  echo "sure which method you want."
  echo
  echo "Syntax:"
  echo "  ./$SCRIPT_NAME src dest  # The src directory must exist."
  echo
  echo "You probably want to run this script with \"background.sh\", so that you get a"
  echo "visual indication when the transfer is complete."
  echo
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  case "$1" in
   *$2) return 0;;
   *)   return 1;;
  esac
}


add_to_comma_separated_list ()
{
  local NEW_ELEMENT="$1"
  local MSG_VAR_NAME="$2"

  if [[ ${!MSG_VAR_NAME} = "" ]]; then
    eval "$MSG_VAR_NAME+=\"$NEW_ELEMENT\""
  else
    eval "$MSG_VAR_NAME+=\",$NEW_ELEMENT\""
  fi
}


# rsync is OK, but I think that rdiff-backup is better.

rsync_method ()
{
  local ARGS=""

  ARGS+=" --no-inc-recursive"  # Uses more memory and is somewhat slower, but improves progress indication.
                               # Otherwise, rsync is almost all the time stuck at a 99% completion rate.
  ARGS+=" --archive"  #  A quick way of saying you want recursion and want to preserve almost everything.
  ARGS+=" --delete --delete-excluded --force"
  ARGS+=" --human-readable"  # Display "60M" instead of "60,000,000" and so on.

  # Unfortunately, there seems to be no way to display the estimated remaining time for the whole transfer.


  local PROGRESS_ARGS=""

  # Instead of making a quiet pause at the beginning, display a file scanning progress indication.
  # That is message "building file list..." and the increasing file count.
  # If you are copying a large number of files and are logging to a file, the log file will be pretty big,
  # as rsync (as of version 3.1.0) seems to refresh the file count in 100 increments. See below for more
  # information about refreshing the progress indication too often.
  add_to_comma_separated_list "flist2" PROGRESS_ARGS

  # Display a global progress indication.
  # If you are copying a large number of files and are logging to a file, the log file will
  # grow very quickly, as rsync (as of version 3.1.0) seems to refresh the accumulated statistics
  # once for every single file. I suspect the console's speed may end up limiting rsync's performance
  # in such scenarios. I have reported this issue, see the following mailing list message:
  #   "Progress indication refreshes too often with --info=progress2"
  #   Wed Jun 11 04:50:26 MDT 2014
  #   https://lists.samba.org/archive/rsync/2014-June/029494.html
  add_to_comma_separated_list "progress2" PROGRESS_ARGS

  # Warn if files are skipped. Not sure if we need this.
  add_to_comma_separated_list "skip1" PROGRESS_ARGS

  # Warn if symbolic links are unsafe. Not sure if we need this.
  add_to_comma_separated_list "symsafe1" PROGRESS_ARGS

  # We want to see how much data there is (the "total size" value).
  # Unfortunately, there is no way to suppress the other useless stats.
  add_to_comma_separated_list "stats1" PROGRESS_ARGS


  ARGS+=" --info=$PROGRESS_ARGS"

  local CMD="rsync $ARGS -- \"$1\" \"$2\""

  echo "$CMD"
  eval "$CMD"
}


# rdiff_backup can keep old files around for a certain amount of time.
# This way, you can recover accidentally-deleted files from a recent backup.

rdiff_backup_method ()
{
  local SRC_DIR="$1"
  local DEST_DIR="$2"

  # When backing up across different operating systems, it may be impractical to map all users and groups
  # correctly. Sometimes you just want to ignore users and groups altogether. Disabling the backing up
  # of ACLs also prevents unnecessary warnings in this scenario.
  local DISABLE_ACLS=true

  if test -e "$DEST_DIR"; then
    local REMOVE_OLDER_THAN="3M"  # 3M means 3 months.
    local CMD1="rdiff-backup  --force --remove-older-than \"$REMOVE_OLDER_THAN\"  \"$DEST_DIR\""

    echo "$CMD1"
    eval "$CMD1"
  fi

  local CMD2="rdiff-backup  --force"

  # Unfortunately, rdiff-backup prints no nice progress indication for the casual user.
  if true; then
    # The default verbosity level is 3.
    # With level 4 you get information about ACL support.
    # With level 5 you start seeing the transferred files, but that makes the backup process too verbose.
    CMD2+=" --verbosity 4"
  fi

  if $DISABLE_ACLS; then
    CMD2+=" --no-acls"
  fi

  # Print some statistics at the end.
  if true; then
    CMD2+=" --print-statistics"
  fi

  CMD2+=" \"$SRC_DIR\" \"$DEST_DIR\""

  echo "$CMD2"
  eval "$CMD2"

  # Verification takes time, so you can disable it if you like.
  if true; then
    local CMD3="rdiff-backup --verify"

    if $DISABLE_ACLS; then
      CMD3+=" --no-acls"
    fi

    CMD3+=" \"$DEST_DIR\""

    echo "$CMD3"
    eval "$CMD3"
  fi
}


# ------- Entry point -------

if [ $# -eq 0 ]; then
  display_help
  exit 0
fi

if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this script without arguments for help."
fi

SRC_DIR="$1"
DEST_DIR="$2"

# In rsync, "src/" means just the contents of src, and "src" means the src itself.
# However, rdiff-backup makes no such distinction.
# For consistency, make all methods behave the same, so that the user
# can switch methods without modifying the paths.

if [[ $SRC_DIR = "/" ]]; then
  abort "The source directory cannot be the root directory."
fi

if [[ $DEST_DIR = "/" ]]; then
  abort "The destination directory cannot be the root directory."
fi

if ! test -d "$SRC_DIR"; then
  abort "The source directory \"$SRC_DIR\" does not exit."
fi

SRC_DIR_ABS="$(readlink -f "$SRC_DIR")"

# Tool 'readlink' should have removed the trailing slash.
# Note that, for rsync, a trailing will be appended.

if str_ends_with "SRC_DIR_ABS" "/"; then
  abort "The destination directory ends with a slash, which is unexpected after canonicalising it."
fi

case "$BACKUP_METHOD" in
  rsync) rsync_method "$SRC_DIR_ABS/" "$DEST_DIR";;
  rdiff-backup) rdiff_backup_method "$SRC_DIR_ABS" "$DEST_DIR";;
  *) abort "Unknown method \"$BACKUP_METHOD\".";;
esac

echo
echo "Backup mirror updated successfully."
