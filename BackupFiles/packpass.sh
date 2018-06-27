#!/bin/bash

# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3
#
# This is the script I normally use to compress all files in the current directory
# and below, encryted with a password.

set -o errexit
set -o nounset
set -o pipefail


declare -r EXIT_CODE_ERROR=1

declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  case "$1" in
     *$2) return $BOOLEAN_TRUE;;
     *)   return $BOOLEAN_FALSE;;
  esac
}


if [ $# -ne 1 ]; then
  abort "You need to specify just one argument with the basename for the compressed file."
fi


UPPERCASE_ARG="${1^^}"

if str_ends_with "$UPPERCASE_ARG" ".7Z"; then
  abort "The specified filename must not end in .7z"
fi


# Quick compression with zip deflate algorithm in fast mode.
# Each file part is around 1,4 GiB, so that 3 of them should fit in a DVD.

printf -v CMD "7za a -t7z %q -m0=Deflate -mx1 -mmt -ms -r -mhe=on -p -v1564866667"  "$1.7z"

echo "$CMD"
eval "$CMD"
