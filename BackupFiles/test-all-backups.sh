#!/bin/bash

# test-all-backups.sh script template version 1.02
#
# This is the script template I normally use to test all backups on my external disks.
#
# You should test every now and then all files on your backup disks. Otherwise,
# the disk may become corrupt without your noticing.
#
# Copyright (c) 2018-2025 R. Diez
# Licensed under the GNU Affero General Public License version 3.

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r TOOL_PAR2="par2"


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit 1
}


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


# Find all .par2 file sets and verify them.
#
# That should also verify the original files the .par2 file set was made of.
# But remember that you need to verify the original files separately at least once.
# Otherwise, if they were corrupt already when the .par2 file set was generated,
# you will not notice.

verify_all_par2_file_sets ()
{
  local BASEDIR="$1"

  BASEDIR="$(readlink --canonicalize-existing --verbose -- "$BASEDIR")"

  pushd "$BASEDIR" >/dev/null

  local FIND_CMD
  printf  -v FIND_CMD  "find %q -iname '*.par2' -printf '%%P\\\\0'"  "."

  local REGEXP_PAR2_FILENAMES_TO_IGNORE="vol[0-9]+\\+[0-9]+\$"

  local -a PAR2_FILE_LIST
  local -i FILENAME_LEN
  local STR

  while IFS='' read -r -d '' FILENAME; do

    # We want to process "basename.par2", but not all other "basename.volxxx+yy.par2" files.

    # First, remove the ".par2" suffix.
    FILENAME_LEN="${#FILENAME}"
    STR="${FILENAME:0:FILENAME_LEN - 5}"

    shopt -s nocasematch  # Under Windows, you can get .par2 or .PAR2 files.

    if [[ $STR =~ $REGEXP_PAR2_FILENAMES_TO_IGNORE ]]; then
      if false; then
        echo "Skipping $FILENAME"
      fi
    else
      PAR2_FILE_LIST+=( "$FILENAME" )
    fi

    shopt -u nocasematch

  done < <( eval "$FIND_CMD" )

  local PAR2_FILENAME
  local VERIFY_PAR2_CMD

  for PAR2_FILENAME in "${PAR2_FILE_LIST[@]:+${PAR2_FILE_LIST[@]}}"
  do
    printf "Verifying %q ...\\n"  "$BASEDIR/$PAR2_FILENAME"

    if true; then

      pushd "$(dirname "$PAR2_FILENAME")" >/dev/null

      printf -v VERIFY_PAR2_CMD  "%q verify -q -- %q"  "$TOOL_PAR2"  "$(basename "$PAR2_FILENAME")"
      echo "$VERIFY_PAR2_CMD"
      eval "$VERIFY_PAR2_CMD"

      popd >/dev/null

      echo

    fi

  done

  popd >/dev/null
}


verify_all_7z_files ()
{
  local BASEDIR="$1"

  BASEDIR="$(readlink --canonicalize-existing --verbose -- "$BASEDIR")"

  pushd "$BASEDIR" >/dev/null

  local FIND_CMD

  printf  -v FIND_CMD  "find %q \\( -iname '*.7z' -o -iname '*.7z.001' \\) -printf '%%P\\\\0'"  "."

  local -a FILE_LIST
  local FILENAME

  while IFS='' read -r -d '' FILENAME; do
    if false; then
      echo "File: $FILENAME"
    fi

    FILE_LIST+=( "$FILENAME" )
  done < <( eval "$FIND_CMD" )


  local COMPRESSED_FILENAME
  local VERIFY_CMD

  for COMPRESSED_FILENAME in "${FILE_LIST[@]:+${FILE_LIST[@]}}"
  do

    pushd "$(dirname "$COMPRESSED_FILENAME")" >/dev/null

    shopt -s nullglob

    declare -a FILES=( *.par2 )  # Alternative: Use Bash built-in 'compgen'.

    if (( ${#FILES[@]} == 0 )); then

      printf "Verifying %q ...\\n"  "$BASEDIR/$COMPRESSED_FILENAME"

      if true; then

        printf -v VERIFY_CMD  "%q t -- %q"  "$TOOL_7Z"  "$(basename "$COMPRESSED_FILENAME")"
        echo "$VERIFY_CMD"
        eval "$VERIFY_CMD"

        echo

      fi

    else

      # We are assuming that the user will want to verify these files using the par2 files instead.
      printf "Skipping %q, because verifying the par2 files will also verify the corresponding 7z files.\\n"  "$BASEDIR/$COMPRESSED_FILENAME"
      echo

    fi

    popd >/dev/null

  done

  popd >/dev/null
}


# ------ Entry Point (only by convention) ------

declare -r TOOL_7Z_NEW="7zz"
declare -r TOOL_7Z_OLD="7z"

# Prefer 7zz to 7z.
if is_tool_installed "$TOOL_7Z_NEW"; then
  declare -r TOOL_7Z="$TOOL_7Z_NEW"
elif is_tool_installed "$TOOL_7Z_OLD"; then
  declare -r TOOL_7Z="$TOOL_7Z_OLD"
else
  abort "Neither '$TOOL_7Z_NEW' nor '$TOOL_7Z_OLD' are not installed. On Ubuntu/Debian, package '7zip' (7zz) is newer and therefore preferable to 'p7zip-full' (7z)."
fi

if false; then
  echo "7z tool found: $TOOL_7Z"
fi


if ! is_tool_installed "$TOOL_PAR2"; then
  abort "The '$TOOL_PAR2' tool is not installed. See the comments in the backup script for a possibly faster alternative version."
fi

echo


verify_all_par2_file_sets "$HOME/some/dir/Rotating Backups 1"
verify_all_par2_file_sets "$HOME/some/dir/Rotating Backups 2"

# Note that 7z will be skipped if par2 files are found next to them,
# because verifying the par2 files will also verify the corresponding 7z files.
# Therefore, do not forget to verify any existing par2 files on those locations.
# Here you should only verify .7z files without corresponding .par2 files.
verify_all_7z_files "$HOME/some/dir/One Time Backups 1"
verify_all_7z_files "$HOME/some/dir/One Time Backups 2"


echo "Finished testing all files. All backups were OK."
