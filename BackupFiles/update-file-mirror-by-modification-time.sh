#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME="update-file-mirror-by-modification-time.sh"
VERSION_NUMBER="1.10"

# Implemented methods are: rsync, rdiff-backup
#
# WARNING: rdiff-backup does not detect moved files. If you reorganise your drive,
#          you may want to purge old data immediately (see REMOVE_OLDER_THAN below),
#          or your destination directory may get much bigger than usual.
#
#          rdiff-backup has given me so much trouble, that I decided I cannot
#          recommend it anymore. Thefore, I changed the default to rsync.
#          Under Cygwin, beware that rsync has been broken for years,
#          see this script's help text below for details.

MIRROR_METHOD="rsync"


declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2015-2018 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "For online backup purposes, sometimes you just want to copy all files across"
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
  echo "If you use the default 'rsync' method instead of the alternative 'rdiff-backup' method,"
  echo "you can set environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use."
  echo "This is important on Microsoft Windows, as Cygwin's rsync is known to have problems."
  echo "See script copy-with-rsync.sh for more information."
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


rsync_method ()
{
  local SRC_DIR="$1"
  local DEST_DIR="$2"

  local ARGS=""

  if false; then
    # If you want to do a dry run, you probably want to specify the 'name' argument
    # in the "--info=" option, so that you can see what would be done.
    ARGS+=" --dry-run"
  fi

  ARGS+=" --no-inc-recursive"  # Uses more memory and is somewhat slower, but improves progress indication.
                               # Otherwise, rsync is almost all the time stuck at a 99% completion rate.

  ARGS+=" --delete --delete-excluded"

  ARGS+=" --force"  # Force deletion of dirs even if not empty.

  ARGS+=" --human-readable"  # Display "60M" instead of "60,000,000" and so on.

  if [[ $OSTYPE = "cygwin" ]]; then
    # See script copy-with-rsync.sh for more information on the problems of Cygwin's rsync.
    ARGS+=" --recursive"
    ARGS+=" --times"  # Copying the file modification times is necessary. Otherwise, all files
                      # will be copied again from scratch the next time around.
  else
    ARGS+=" --archive"  #  A quick way of saying you want recursion and want to preserve almost everything.
  fi

  # You may have to add flag --modify-window=1 if you are copying to or from a FAT filesystem,
  # because they represent times with a 2-second resolution.

  # Say we are backing up under Linux from a Linux filesystem to a Windows network drive mounted
  # with "mount -t cifs". If a file in the Linux filesystem is a symlink to another file (even if the target
  # file falls under the same set being backed-up), then the complete mirroring operation will fail
  # with error "[Errno 95] Operation not supported".
  #
  # Unfortunately, this switch generates warnings like this:
  #   skipping non-regular file "xxx/yyy.zzz"
  # I have not found a way yet to suppress those warnings.
  ARGS+=" --no-links"


  # About resuming partially-transferred files.
  #
  # By default, rsync will delete any partially-transferred file if the transfer is interrupted.
  # That wastes a lot of time if the files are big. Unfortunately, there is no way to make
  # rsync safely resume file transfers when copying between local filesystems, at least
  # as of version 3.1.2.
  #
  # --append is dangerous, because:
  #   1) It implies --inplace, so if the transfer is interrupted, other applications may assume that the file
  #      is complete when in fact it may not be yet.
  #   2) If the "last modified" timestamp changes, --append still assumes that the first part of the file
  #      has remained unchanged. However, I would not normally assume that this is the case,
  #      especially for a file mirror operation.
  #      --append-verify would help here, but that does not make much sense when copying locally, because both files
  #      have to be read completely at the end in order to calculate the checksum.
  #
  # --partial does check the "last modified" timestamp, but it does not resume any incomplete file transfers.
  #   It just leaves the incomplete file behind, but it will be deleted next time around, thus restarting
  #   the transfer from scratch, if you do not specify --append too.
  #   However, after an interrupted transfer, other applications may assume that the file is complete when
  #   in fact it may not be yet.
  #   That is the reason why --partial-dir is better. The destination file only gets its final name
  #   when the transfer was successfully completed.
  #
  # --partial-dir seems the right answer, but does not quite cut it.
  #
  #   I could not find any official end-user documentation about rsync's behaviour with this option,
  #   so I did some empiric observation when copying files between local drives with rsync version 3.1.2.
  #   This is what I saw:
  #
  #   Say rsync starts transferring a file named "MyFile.data".
  #   It will create a random filename like ".MyFile.data.Eu4yFt" where the file should land.
  #   If the transfer gets interrupted, a subdirectory called ".rsync-partial" is created,
  #   and the file is moved there, but renamed to the original filename "MyFile.data".
  #   Next time around, the file is moved back to where it should be, named again ".MyFile.data.Eu4yFt",
  #   directory ".rsync-partial" is deleted, and the transfer continues.
  #   When the transfer is completed successfully, the file is renamed to the original name.
  #
  #   The trouble is, resuming breaks down when copying across local filesystems, because
  #   option --whole-file is implied. Therefore, the partially-transmitted file will be deleted
  #   next time around, and transfer will start from scratch.
  #   Using --no-whole-file actually makes no sense for local transfers, as both source and destinations files
  #   would be completely read before copying any data.
  #
  #   There is another problem: if the transfer stops abruptly, for example, because the rsync process
  #   gets killed, then files with random filenames like ".MyFile.data.Eu4yFt" are left behind.
  #   In this case, rsync does not get a chance to create the ".rsync-partial" subdirectory.
  #   Next time around, such files are not recognised as partially-completed transfers,
  #   so they are ignored and remain on the destination filesystem (!).
  #   If you are using --delete to create a file mirror, such files should be removed automatically.
  #
  # Therefore, this script will make rsync always restart interrupted file transfers from scratch.
  # Try to avoid large files if you can. For example, when compressing many files with 7z,
  # you can always split the resulting tarball into smaller files ("volumes") with the -v option.


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

  # Add the 'name' flag to print a new line per filename being copied or deleted.
  # If you have many small files, the log output may be too long.
  if false; then
    add_to_comma_separated_list "name" PROGRESS_ARGS
  fi

  ARGS+=" --info=$PROGRESS_ARGS"

  local CMD

  printf -v CMD  "%q %s -- %q  %q"  "${PATH_TO_RSYNC:-rsync}"  "$ARGS"  "$SRC_DIR"  "$DEST_DIR"

  echo "$CMD"
  eval "$CMD"
}


# rdiff_backup can keep old files around for a certain amount of time.
# This way, you can recover accidentally-deleted files from a recent backup.

rdiff_backup_method ()
{
  local SRC_DIR="$1"
  local DEST_DIR="$2"

  local SRC_DIR_QUOTED
  local DEST_DIR_QUOTED

  printf -v SRC_DIR_QUOTED  "%q" "$SRC_DIR"
  printf -v DEST_DIR_QUOTED "%q" "$DEST_DIR"

  # When backing up across different operating systems, it may be impractical to map all users and groups
  # correctly. Sometimes you just want to ignore users and groups altogether. Disabling the backing up
  # of ACLs also prevents unnecessary warnings in this scenario.
  local DISABLE_ACLS=true

  # If you have been backing up with rsync, and then want to switch to the rdiff-backup method,
  # the first time you run rdiff-backup the destination directory will not contain the rdiff-backup
  # metadata directory. In this case, we should not try to run a --remove-older-than command,
  # because it will always fail.
  local RDIFF_METADATA_DIRNAME="rdiff-backup-data"

  if test -d "$DEST_DIR" && test -d "$DEST_DIR/$RDIFF_METADATA_DIRNAME"; then
    local REMOVE_OLDER_THAN="3M"  # 3M means 3 months.

    local CMD1="rdiff-backup  --force --remove-older-than \"$REMOVE_OLDER_THAN\"  $DEST_DIR_QUOTED"

    echo "$CMD1"
    eval "$CMD1"
  fi

  # We need "--force" in case the previous backup was interrupted (for example, if rdiff-backup was stopped
  # with Ctrl+C), which can happen rather often if your backups are large. Otherwise, you get this error message:
  #   Fatal Error: It appears that a previous rdiff-backup session with process
  #   id xxx is still running.  If two different rdiff-backup processes write
  #   the same repository simultaneously, data corruption will probably
  #   result.  To proceed with regress anyway, rerun rdiff-backup with the
  #   --force option.
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

  # Say we are backing up under Linux from a Linux filesystem to a Windows network drive mounted
  # with "mount -t cifs". If a file in the Linux filesystem is a symlink to another file (even if the target
  # file falls under the same set being backed-up), then the complete backup operation will fail
  # with error "[Errno 95] Operation not supported".
  CMD2+=" --exclude-symbolic-links"

  # Print some statistics at the end.
  if true; then
    CMD2+=" --print-statistics"
  fi

  CMD2+="  $SRC_DIR_QUOTED  $DEST_DIR_QUOTED"

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
  local TMP_FILENAME
  TMP_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.txt")"
  if false; then
    echo "TMP_FILENAME: $TMP_FILENAME"
  fi

  # Try to delete the temporary file on exit. It is no hard guarantee,
  # but it usually works. If not, the operating system will hopefully
  # clean the temporary directory every now and then.
  printf -v TMP_FILENAME_QUOTED "%q" "$TMP_FILENAME"
  # shellcheck disable=SC2064
  trap "rm -f -- $TMP_FILENAME_QUOTED" EXIT


  echo "$CMD2"
  eval "$CMD2 | tee \"$TMP_FILENAME\""

  if ! test -d "$DEST_DIR/$RDIFF_METADATA_DIRNAME"; then
    abort "After running rdiff-backup, the following expected directory was not found: \"$DEST_DIR/$RDIFF_METADATA_DIRNAME\"."
  fi

  check_no_rdiff_backup_errors "$TMP_FILENAME"

  # Verification takes time, so you can disable it if you like.
  if true; then
    local CMD3="rdiff-backup --verify"

    if $DISABLE_ACLS; then
      CMD3+=" --no-acls"
    fi

    CMD3+="  $DEST_DIR_QUOTED"

    echo "$CMD3"
    eval "$CMD3"
  fi
}


# It is hard to believe that a backup tool like rdiff-backup still yields a zero (success)
# exit code when some files fail to backup.
#
# This routine captures the number of failed files from rdiff-backup's text output,
# and aborts if it is not zero.

check_no_rdiff_backup_errors ()
(  # Instead of '{', use a subshell, so that any changed shopt options get restored on exit.

  local TMP_FILENAME="$1"

  shopt -s nocasematch

  # The usual text is:  --------------[ Session statistics ]--------------
  # We look for some starting "---" characters, some ending "---" characters,
  # and the 2 words "session statistics" in a case-insensitive manner somewhere in between.
  local STATISTICS_BANNER_REGEX="^---.*session statistics.*---\$"

  # We are looking for a line like this: Errors 0
  local ERRORS_REGEX="errors[[:space:]]+([[:digit:]]+)[[:space:]]*\$"

  local STATE="searchingForSessionStats"
  local LINE

  while read -r LINE
  do
    if false; then
      echo "Line: $LINE"
    fi

    case "$STATE" in
      searchingForSessionStats)

        if [[ $LINE =~ $STATISTICS_BANNER_REGEX ]] ; then
          STATE="searchingForErrorsLine"
        fi

        ;;

      searchingForErrorsLine)
        if [[ $LINE =~ $ERRORS_REGEX ]] ; then

          local ERROR_COUNT="${BASH_REMATCH[1]}"

          if false; then
            echo "Error count: $ERROR_COUNT"
          fi

          if [[ $ERROR_COUNT != "0" ]] ; then
            abort "Some files failed to backup."
          fi

          STATE="noErrorsFound"
        fi

        ;;

      noErrorsFound) ;;

      *) abort "Invalid state \"$STATE\".";;
    esac
  done <"$TMP_FILENAME"


  if [[ $STATE != "noErrorsFound" ]]; then
    abort "Could not determine whether any files failed to backup."
  fi
)


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
  abort "The source directory \"$SRC_DIR\" does not exist."
fi

SRC_DIR_ABS="$(readlink  --verbose  --canonicalize-existing -- "$SRC_DIR")"


# Sanity check: Make sure that the source directory is not empty.
# This can easily happen if you have an empty directory intended to act
# as a mountpoint for a network drive, but you forget to mount the network drive
# before running this script. An empty source directory would mark all files
# in the mirror as "deleted", which is a rather unlikely operation for a file mirror.

if is_dir_empty "$SRC_DIR_ABS"; then
  abort "The source directory has no files, which is unexpected."
fi


# Tool 'readlink' should have removed the trailing slash.
# Note that, for rsync, a trailing will be appended.

if str_ends_with "SRC_DIR_ABS" "/"; then
  abort "The destination directory ends with a slash, which is unexpected after canonicalising it."
fi


RDIFF_BACKUP_DIR="$DEST_DIR/rdiff-backup-data"

if [ -d "$RDIFF_BACKUP_DIR" ] && [ "$MIRROR_METHOD" != "rdiff-backup" ]; then
  MSG="The destination directory looks like it was created with rdiff-backup. If you update it"
  MSG+=" with a different mirror method, the rdiff-backup metadata will become out of sync."
  MSG+=" Alternatively, delete directory \"$RDIFF_BACKUP_DIR\" beforehand."
  abort "$MSG"
fi


case "$MIRROR_METHOD" in
  rsync) rsync_method "$SRC_DIR_ABS/" "$DEST_DIR";;
  rdiff-backup) rdiff_backup_method "$SRC_DIR_ABS" "$DEST_DIR";;
  *) abort "Unknown method \"$MIRROR_METHOD\".";;
esac

echo
echo "File mirror updated successfully."
