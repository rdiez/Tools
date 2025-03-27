#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.10"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}

is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


declare -r RSYNC_BWLIMIT_ENV_VAR_NAME="RSYNC_BWLIMIT"

display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2014-2025 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "Most of the time, I just want to copy files around with \"cp\", but, if a long transfer"
  echo "gets interrupted, next time around I want it to resume where it left off, and not restart"
  echo "from the beginning."
  echo
  echo "That's where rsync comes in handy. The trouble is, I can never remember the right options"
  echo "for rsync, so I wrote this little wrapper script to help."
  echo
  echo "Syntax:"
  echo "  ./$SCRIPT_NAME src dest  # Copies src (file or dir) to dest (file or dir)"
  echo "  ./$SCRIPT_NAME src_dir/ dest_dir  # Copies src_dir's contents to dest_dir"
  echo
  echo "This script assumes that the contents of each file has not changed in the meantime."
  echo "If you interrupt this script, modify a file, and resume the copy operation, you will"
  echo "end up with a mixed mess of old and new file contents."
  echo
  echo "You probably want to run this script with \"background.sh\", so that you get a"
  echo "visual indication when the transfer is complete."
  echo
  echo "Environment variables:"
  echo "- Use environment variable PATH_TO_RSYNC to specify an alternative rsync tool to use."
  echo "  This is important on Microsoft Windows, as Cygwin's rsync is known to have problems."
  echo "  See this script's source code for details."
  echo "- Use environment variable $RSYNC_BWLIMIT_ENV_VAR_NAME in order to pass a value"
  echo "  for rsync's option '--bwlimit', which can limit the bandwidth usage."
  echo
  echo "DETECTING DATA CORRUPTION"
  echo "I have yet to copy a large amount of files without some data corruption somewhere."
  echo "I have had such trouble restarting file transfers over the network against Windows PCs using SMB/CIFS."
  echo "My old laptop had silent USB data corruption issues, and slightly unreliable hard disks"
  echo "also show up from time to time. No wonder I have become paranoid over the years."
  echo "Your best bet is to calculate checksums of all files at the source, and verify them at the destination."
  echo "Checksum creation:"
  echo "  rhash --recursive --crc32 --simple --percents --output=\"subdir-file-crcs.txt\" -- \"subdir/\""
  echo "Checksum verification:"
  echo "  rhash --check --recursive --crc32 --simple --skip-ok -- \"subdir-file-crcs.txt\""
  echo "Further notes:"
  echo "- When creating the hashes, rhash option \"--update\" does not work well. I could not make it"
  echo "  add new file checksums to the list in a recursive manner."
  echo "  This is allegedly fixed in rhash v1.3.9, see modified --update=filename argument."
  echo "- When verifying, do not enable the progress indication. Otherwise, it is hard to see"
  echo "  which files have failed. This is unfortunate."
  echo "- Consider using GNU Parallel or \"xargs --max-procs\" if the CPU becomes a bottleneck"
  echo "  (which is unusual for simple checksums like CRC-32)."
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


# ------ Entry Point (only by convention) ------

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

ARGS+=" --append"   # Continue partially-transferred files.
ARGS+=" --human-readable"  # Display "60M" instead of "60,000,000" and so on.


if is_var_set "$RSYNC_BWLIMIT_ENV_VAR_NAME"; then

  printf -v TMP -- "--bwlimit=%q" "${!RSYNC_BWLIMIT_ENV_VAR_NAME}"

  ARGS+=" $TMP"

fi


PROGRESS_ARGS=""

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

# Unfortunately, there seems to be no way to display the estimated remaining time for the whole transfer.

ARGS+=" --info=$PROGRESS_ARGS"


printf -v CMD "%q %s -- %q  %q"  "${PATH_TO_RSYNC:-rsync}"  "$ARGS"  "$1"  "$2"

echo "$CMD"
eval "$CMD"

echo
echo "Copy operation finished successfully."
