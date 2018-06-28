#!/bin/bash

# This tool copies a file and keeps adding the given padding byte at the end
# until the specified file size has been reached.
#
# Copyright (c) 2015-2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Trace execution of this script.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if [ $# -ne 4 ]; then
  abort "Invalid command-line arguments. Please specify <source file name>, <destination file name>, <target size> and <padding byte value>. Ssee this script's source code for more information."
fi


# The size in bytes and the padding byte value can be given in:
# - decimal     like "10"   (must be WITHOUT leading zero)
# - octal       like "010"  (must have a leading zero)
# - hexadecimal like "0x10"

SOURCE_FILENAME="$1"
DESTINATION_FILENAME="$2"
declare -i TARGET_SIZE="$(( $3 ))"
declare -i PADDING_BYTE_VALUE="$(( $4 ))"


declare -i EXISTING_FILE_SIZE
EXISTING_FILE_SIZE="$(stat -c "%s" -- "$SOURCE_FILENAME")"

if (( EXISTING_FILE_SIZE > TARGET_SIZE )); then
  abort "The file size is greater than the target size."
fi

declare -i PAD_COUNT="$(( TARGET_SIZE - EXISTING_FILE_SIZE ))"

cp -- "$SOURCE_FILENAME" "$DESTINATION_FILENAME"


# This is rather slow. We could optimise it by growing the string exponentially.

printf -v PADDING_BYTE_IN_OCTAL "%03o" "$PADDING_BYTE_VALUE"


# This is rather slow. We could optimise it by telling dd to read data in chunks.

dd if=/dev/zero ibs=1 count="$PAD_COUNT" | tr "\\000" "\\$PADDING_BYTE_IN_OCTAL" >> "$DESTINATION_FILENAME"
