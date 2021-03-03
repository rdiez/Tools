#!/bin/bash

# This script downloads the given URL to a fixed filename under your home directory,
# and runs HTML 'tidy' against it for lint purposes.
#
# I use it from Emacs to check if an web page generates any HTML warnings.
#
# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="TidyUrl.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


main ()
{
  local URL="$1"

  local DOWNLOAD_DIR="$HOME/.$SCRIPT_NAME-tmp-dir"
  mkdir --parents -- "$DOWNLOAD_DIR"

  # We could rotate the last N files like script background.sh does.
  local TMP_FILENAME="$DOWNLOAD_DIR/$SCRIPT_NAME-tmp.html"

  local CMD

  CMD="curl"

  # Option --location makes curl follow redirects.
  # It does not work with HTML redirects like:  <meta http-equiv="refresh" ...>
  CMD+=" --location"

  CMD+=" --silent"

  printf -v CMD  "$CMD --output %q  %q"  "$TMP_FILENAME"  "$URL"

  echo "$CMD"
  eval "$CMD"

  printf -v CMD "tidy --gnu-emacs yes  -quiet -output /dev/null  %q"  "$TMP_FILENAME"

  echo "$CMD"

  # I am running this script from other scripts, and there is quite a lot of console output.
  # Tool 'tidy' does not output anything at all if there are no warnings.
  # So I added these markers, in order to quickly locate any HTML warnings in the output.
  echo
  echo "--- Tidy output begin ---"
  eval "$CMD"

  echo "--- Tidy output end   ---"
  echo

  echo "Finished."
}


if (( $# != 1 )); then
  abort "You need to pass a single argument with the URL."
fi

main "$1"
