#!/bin/bash

# This script deletes files from one directory which are duplicated in another reference directory.
# The duplicate files must have the same relative path in both directories, the same filename and the same contents.
#
# If you have two directory structures which are mostly the same, but you have modified files in both copies,
# and you do not know anymore what files you should keep, merge or delete, this script will help you with
# a first step of deleting obvious duplicates.
#
# The script was inspired by an excellent answer to this question:
#
#   Can I find duplicate files with the same path in different locations?
#   https://superuser.com/questions/1763042/can-i-find-duplicate-files-with-the-same-path-in-different-locations
#   Answer from: Kamil Maciorowski
#
# You can of course directly use the answer above, but this standalone script improves a little on it:
# - The 'find' command you need to use becomes shorter and easier to build.
# - In "dry run" mode, it prints the names of the files which would be deleted.
# - It is more robust. An error condition from 'cmp' will be properly detected, and more checking is generally performed.
# - The shell code below is easier to modify for your needs, should you want different behaviour.
#
# How to use this script:
#
#   cd "dir/to/delete/files/from"
#   find . -type f -exec "path/to/this/script" "dir/to/keep/intact" dryrun {} +
#
#   Change 'dryrun' to 'delete' above to actually delete any duplicate files found.
#
# Copyright (c) 2023 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


# ------- Entry Point (only by convention) -------

if (( $# < 3 )); then
  abort "Invalid number of command-line arguments."
fi

declare -r DIRECTORY_TO_KEEP_INTACT="$1"
declare -r OPERATION="$2"

if ! [ -d "$DIRECTORY_TO_KEEP_INTACT" ]; then
  abort "The directory to keep intact does not exist: $DIRECTORY_TO_KEEP_INTACT"
fi

# We do not really need to use DIRECTORY_TO_KEEP_INTACT_ABS during checking later,
# but then we should remove any trailing slash ('/') from DIRECTORY_TO_KEEP_INTACT beforehand.

DIRECTORY_TO_KEEP_INTACT_ABS="$(readlink --canonicalize --verbose -- "$DIRECTORY_TO_KEEP_INTACT")"

if [[ $PWD = "$DIRECTORY_TO_KEEP_INTACT_ABS" ]]; then
  abort "The current directory and the directory to keep intact are the same: $PWD"
fi

if [[ "$DIRECTORY_TO_KEEP_INTACT_ABS" = "/" ]]; then
  # If we were to allow the root directory, we need to amend the logic further down,
  # so that you do not end up with filenames like "//my-file".
  abort "The directory to keep intact cannot be the root directory ('/')."
fi


declare -r OP_DRY_RUN="dryrun"
declare -r OP_DELETE="delete"

case "$OPERATION" in
  "$OP_DRY_RUN") REALLY_DELETE=false ;;
  "$OP_DELETE")  REALLY_DELETE=true  ;;
  *) abort "Invalid operation \"$OPERATION\". Specify either '$OP_DRY_RUN' or '$OP_DELETE'." ;;
esac

# Remove the first 2 arguments, the rest are the filenames to process.
shift
shift

# Showing each filename is a kind of progress indicator, but there can be too many files.
declare -r SHOW_EACH_FILENAME=false

# Mainly useful when debugging this script.
declare -r ENABLE_TRACING=false

declare -i DELETE_COUNT=0

if ! $SHOW_EACH_FILENAME; then
  # Show some message, or there is no indication at all that something is going on.
  # Show hint "a batch of" because tool 'find' may run this script several times.
  echo "Processing a batch of $# file(s)..."
fi


# The default array for the 'for' statement is "$@", that is, the rest of the command-line arguments.

for FILENAME; do

  if $SHOW_EACH_FILENAME; then
    echo "Processing: $FILENAME"
  fi

  if ! [ -f "$DIRECTORY_TO_KEEP_INTACT_ABS/$FILENAME" ]; then

    if $ENABLE_TRACING; then
      echo "Does not exist in reference directory: $FILENAME"
    fi

    continue
  fi


  if $ENABLE_TRACING; then
    echo "Comparing file: $FILENAME"
  fi

  set +o errexit

  cmp --quiet -- "$FILENAME" "$DIRECTORY_TO_KEEP_INTACT_ABS/$FILENAME"

  declare -i CMP_EXIT_CODE="$?"

  set -o errexit


  case "$CMP_EXIT_CODE" in

    0)  # Both files have the same content, so the current file should be deleted.

        if $REALLY_DELETE; then

          if $ENABLE_TRACING; then
            echo "Deleting file with same content: $FILENAME"
          fi

          # Option "--interactive=never" deletes write-protected files without prompting.
          rm --interactive=never -- "$FILENAME"

        else

          # We could do here:
          #   if $ENABLE_TRACING; then
          # However, if the user is doing a dry run, he/she probably wants to see what files would be deleted.

          if true; then
            echo "Deletion candidate: $FILENAME"
          else
            ABSOLUTE_PATH="$(readlink --canonicalize --verbose -- "$FILENAME")"
            echo "Deletion candidate: $ABSOLUTE_PATH"
          fi

        fi

        DELETE_COUNT+=1

        ;;

    1)  # The files have different content, so the current file should not be deleted.

       if $ENABLE_TRACING; then
         echo "The file content is different: $FILENAME"
       fi

       ;;

    *) abort "The 'cmp' command failed with exit code $CMP_EXIT_CODE for file: $FILENAME" ;;

  esac

done


# If command 'find' calls this script several times, we will show separate deletion counts,
# as it is hard to aggregate them across script calls.

if $REALLY_DELETE; then
  echo "$DELETE_COUNT file(s) deleted."
else
  echo "$DELETE_COUNT file(s) would have been deleted."
fi
