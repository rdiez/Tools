#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


SCRIPT_NAME="move-with-rsync.sh"
VERSION_NUMBER="1.03"


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
  echo "If you try to move files and subdirectores with 'mv' overwriting any existing ones, "
  echo "you may come across the infamous \"directory not empty\" error message."
  echo "This script uses rsync to work-around this issue."
  echo
  echo "Unfortunately, rsync does not remove the source directories. This script deletes them afterwards, "
  echo "but, if a new file comes along in between, it will be deleted even though it was not moved."
  echo
  echo "Syntax:"
  echo "  ./$SCRIPT_NAME src dest  # Movies src (file or dir) to dest (file or dir)"
  echo "  ./$SCRIPT_NAME src_dir/ dest_dir  # Moves src_dir's contents to dest_dir"
  echo
  echo "You probably want to run this script with \"background.sh\", so that you get a"
  echo "visual indication when the transfer is complete."
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
ARGS+=" --archive"  #  A quick way of saying you want recursion and want to preserve almost everything.
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

CMD="rsync $ARGS -- \"$1\" \"$2\""

echo $CMD
eval $CMD

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
