#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME="move-with-rsync.sh"
VERSION_NUMBER="1.07"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2015-2017 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "If you try to move files and subdirectores with 'mv' overwriting any existing ones,"
  echo "you may come across the infamous \"directory not empty\" error message."
  echo "This script uses rsync to work-around this issue."
  echo
  echo "Unfortunately, rsync does not remove the source directories. This script deletes them afterwards,"
  echo "but, if a new file comes along in between, it will be deleted even though it was not moved."
  echo
  echo "Syntax:"
  echo "  ./$SCRIPT_NAME src dest  # Moves src (file or dir) to dest (file or dir)"
  echo "  ./$SCRIPT_NAME src_dir/ dest_dir  # Moves src_dir's contents to dest_dir"
  echo
  echo "You probably want to run this script with \"background.sh\", so that you get a"
  echo "visual indication when the transfer is complete."
  echo
  echo "Use environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use."
  echo "This is important on Microsoft Windows, as Cygwin's rsync is known to have problems."
  echo "See this script's source code for details."
  echo
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


# ------- Entry point -------

if [ $# -eq 0 ]; then
  display_help
  exit 0
fi

if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. Run this script without arguments for help."
fi


ARGS=""

ARGS+=" --no-inc-recursive"  # Uses more memory and is somewhat slower, but improves progress indication.
                             # Otherwise, rsync is almost all the time stuck at a 99% completion rate.

if [[ $OSTYPE = "cygwin" ]]; then

  # Using rsync on Windows is difficult. Over the years, I have encountered many problems with Cygwin's rsync.
  # Some versions were just very slow, some other would hang after a while, and all of them had problems
  # with Windows' file permissions.
  #
  # I have always used rsync to just copy files locally (not in a client/server environment),
  # with a user account that has full access to all files. This is arguably the easiest scenario,
  # but it does not work straight away nevertheless.
  #
  # The first thing to do is to use cwRsync instead of Cygwin's rsync. cwRsync's Free Edition will suffice.
  # Although it brings its own Cygwin DLL with it, this rsync version works fine.
  #
  # Then you need to avoid rsync's "--archive" flag, because it will attempt to copy file permissions,
  # which has never worked properly for me. By the way, flag " --no-perms" seems to have no effect.
  #
  # If you are connecting to a network drive where you have full permissions,
  # and you create a new directory with Windows' File Explorer, these are the
  # Cygwin permissions you get, viewed on the PC sharing the disk:
  #
  #   d---rwxrwx+ 1 Unknown+User Unknown+Group  MyDir
  #
  # However, cwRsync generates the following permissions:
  #
  #   drwxrwx---+ 1 Unknown+User Unknown+Group MyDir
  #
  # Normally, it does not matter much, as you still have read/write access to the files, but for some
  # operations, like renaming directories, Windows Explorer will ask for admin permissions.
  #
  # The detailed permissions entries, as viewed with File Explorer's permissions dialog, are also different.
  #
  # A single file looks like this:
  #
  #    -rwxrwx---+  SomeFile.txt
  #
  # With rsync's option "--chmod=ugo=rwX", which is often given as a work-around for the file permission issues,
  # you get the following permissions:
  #
  #    -rwxrwxr-x+  SomeFile.txt
  #
  # That is, "--chmod" does have an effect, but only on the permissions for "other" users (in this case),
  # which it does not really help.
  #
  # After finishing the copy operations, you can try using my ResetWindowsFilePermissions.bat script
  # so that the copied files end up with the same permissions as if you had copied them with
  # Windows File Explorer. Alternatively, these are the steps in order to reset the permissions manually (with the mouse):
  #
  # 1) Create a top-level directory in the usual way with Windows' File Explorer.
  # 2) Temporarily move the just-copied directory (or directories) below the new top-level one.
  # 3) Take ownership of all files inside the just-copied directory.
  # 4) Reset all permissions of the just-copied directory to the ones inherited from the new top-level directory.
  # 5) Move back the just-copied directory to its original location.

  ARGS+=" --recursive"
  ARGS+=" --times"  # Copying the file modification times is necessary. Otherwise, all files
                    # will be copied again from scratch the next time around.

else

  ARGS+=" --archive"  #  A quick way of saying you want recursion and want to preserve almost everything.

fi

# You may have to add flag --modify-window=1 if you are copying to or from a FAT filesystem,
# because they represent times with a 2-second resolution.

ARGS+=" --human-readable"  # Display "60M" instead of "60,000,000" and so on.
ARGS+=" --remove-source-files"  # This is the "move" semantic.

# Unfortunately, there seems to be no way to display the estimated remaining time for the whole transfer.


PROGRESS_ARGS=""

# Instead of making a quiet pause at the beginning, display a file scanning progress indication.
# That is message "building file list..." and the increasing file count.
# If you are moving a large number of files and are logging to a file, the log file will be pretty big,
# as rsync (as of version 3.1.0) seems to refresh the file count in 100 increments. See below for more
# information about refreshing the progress indication too often.
add_to_comma_separated_list "flist2" PROGRESS_ARGS

# Display a global progress indication.
# If you are moving a large number of files and are logging to a file, the log file will
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

printf -v CMD "%q %s -- %q  %q"  "${PATH_TO_RSYNC:-rsync}"  "$ARGS"  "$1"  "$2"

echo "$CMD"
eval "$CMD"

echo "Removing any source directories left by rsync..."

case "$1" in
*/)
    # echo "Filename ends in a slash."
    pushd "$1" >/dev/null
    find . -mindepth 1 -delete
    popd >/dev/null
    ;;
*)
    # echo "Filename does not end in a slash."

    if [ -d "$1" ]; then
      # echo "Source is a directory."
      rm -rf -- "$1"
    else
      # echo "Source is a file."
      : # Nothing to do, the file should not be there anymore.
    fi

    ;;
esac

echo
echo "Move operation finished successfully."
