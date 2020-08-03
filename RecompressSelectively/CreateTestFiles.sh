#!/bin/bash

# This script generates test files for script RecompressSelectively.sh
#
# Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


create_pseudorandom_file ()
{
  local -r FILENAME="$1"
  local -r -i KB_COUNT="$2"

  # Each line has random digits from 0 to 9.
  # This data will compress with zip at around 50%.

  local -r -i LINE_LEN=99
  local -i INDEX
  local STR

  for (( INDEX = 0 ; INDEX < LINE_LEN; ++INDEX )); do
    STR+="\$(( RANDOM % 10 ))"
  done

  local -r -i LINE_COUNT="$(( KB_COUNT * 10 ))"

  {
    for (( LINE_INDEX = 0 ; LINE_INDEX < LINE_COUNT ; ++LINE_INDEX )); do
      eval "echo $STR"
    done
  } >"$FILENAME"
}


create_test_subdir ()
{
  local -r SUBDIR="$1"
  local -r EXTRA_FILENAME="$2"
  local -r EXTRA_FILE_CONTENTS="$3"

  echo "Creating test subdir $SUBDIR ..."

  local DELETE_TMP_DIR_CMD

  printf -v DELETE_TMP_DIR_CMD  "rm -rf %q"  "$TMP_DIR_ABS"

  eval "$DELETE_TMP_DIR_CMD"

  mkdir --parents "$TMP_DIR_ABS"

  pushd "$TMP_DIR_ABS" >/dev/null

  create_pseudorandom_file "$SUBDIR-data.txt" "100"


  echo "Contents of SomeOtherFile.txt ." >"SomeOtherFile.txt"


  echo "$EXTRA_FILE_CONTENTS" >"$EXTRA_FILENAME"


  zip --quiet --recurse-paths -9 "$SUBDIR-data.zip" .

  popd >/dev/null


  mkdir -- "$SUBDIR"

  mv -- "$TMP_DIR_ABS/$SUBDIR-data.zip" "$SUBDIR/"

  eval "$DELETE_TMP_DIR_CMD"
}


if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. See this tool's source code for more information."
fi

# Make the pseudorandom data repeatable.
RANDOM=1

declare -r DEST_DIR="$1"

rm -rf -- "$DEST_DIR"

mkdir --parents -- "$DEST_DIR"

pushd "$DEST_DIR" >/dev/null

declare -r DEST_DIR_ABS="$PWD"

declare -r TMP_SUBDIR="tmp"

declare -r TMP_DIR_ABS="$DEST_DIR_ABS/$TMP_SUBDIR"


mkdir "FilesToProcess"

pushd "FilesToProcess" >/dev/null


declare -r FILENAME_TO_REPLACE_1="FileToReplace1.txt"
declare -r OLD_CONTENT_TO_REPLACE_1="OldContent1"
declare -r NEW_CONTENT_TO_REPLACE_1="NewContent1"

declare -r FILENAME_TO_REPLACE_2="FileToReplace2.txt"
declare -r OLD_CONTENT_TO_REPLACE_2="OldContent2"
declare -r NEW_CONTENT_TO_REPLACE_2="NewContent2"

mkdir "Test1"

pushd "Test1" >/dev/null

create_test_subdir "Sub1" "SomeOtherFile2.txt" "SomeOtherFile2 contents."

echo "Not actually a zip file." >"Sub1/NotActuallyAZipFile.zip"

create_test_subdir "Sub2" "$FILENAME_TO_REPLACE_1" "$OLD_CONTENT_TO_REPLACE_1"

# Make the .zip extension uppercase.
mv "Sub2/Sub2-data.zip" "Sub2/Sub2-data.ZIP"

create_test_subdir "Sub3" "$FILENAME_TO_REPLACE_2" "$OLD_CONTENT_TO_REPLACE_2"

popd >/dev/null


mkdir "Test2"

pushd "Test2" >/dev/null

create_test_subdir "Sub1" "SomeOtherFile2.txt" "SomeOtherFile2 contents."

create_test_subdir "Sub2" "SomeOtherFile2.txt" "SomeOtherFile2 contents."

create_test_subdir "Sub3" "$FILENAME_TO_REPLACE_1" "$NEW_CONTENT_TO_REPLACE_1"

create_test_subdir "Sub4" "$FILENAME_TO_REPLACE_2" "$NEW_CONTENT_TO_REPLACE_2"

popd >/dev/null

popd >/dev/null

mkdir "ReplacementFiles"


pushd "ReplacementFiles" >/dev/null

echo "$NEW_CONTENT_TO_REPLACE_1" >"$FILENAME_TO_REPLACE_1"
echo "$NEW_CONTENT_TO_REPLACE_2" >"$FILENAME_TO_REPLACE_2"

popd >/dev/null


popd >/dev/null
