#!/bin/bash

# Version 1.00.
#
# This scripts opens a file explorer on the given file or directory.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


verify_start_detached_is_installed ()
{
  if is_tool_installed "$SDNAME"; then
    return
  fi

  abort "This script needs script $SDNAME . Please make sure $SDNAME is on the PATH."
}


# ------- Entry point -------

declare -r ARG_ERR_MSG="This script expects exactly one argument with the filename or directory name, optionally after an '--' separator."

case $# in

  1) if [[ $1 = "--" ]]; then
       abort "$ARG_ERR_MSG"
     fi;;

  2) if [[ $1 = "--" ]]; then
       shift
     else
       abort "$ARG_ERR_MSG"
     fi;;

  *) abort "$ARG_ERR_MSG";;

esac


declare -r FILE_OR_DIR_NAME="$1"


# You normally need to start the file manager process in the background (with StartDetached.sh or similar).
# Otherwise, if this is the first file manager window, most file managers do not terminate until
# the last window is gone.
declare -r SDNAME="StartDetached.sh"


if false; then

  # Here you can manually set the command you want. Otherwise, see the automatic desktop environment detection logic below.

  if false; then

    verify_start_detached_is_installed

    printf -v CMD  "%q  nautilus --no-desktop --browser -- %q"  "$SDNAME"  "$FILE_OR_DIR_NAME"

  else

    if [ -d "$FILE_OR_DIR_NAME" ]; then
      NAME_TO_OPEN="$FILE_OR_DIR_NAME"
    else
      # Open the containing directory.
      NAME_TO_OPEN="$(dirname -- "$FILE_OR_DIR_NAME")"
    fi

    printf -v CMD  "xdg-open %q"  "$NAME_TO_OPEN"

  fi

else

  verify_start_detached_is_installed

  case "${XDG_CURRENT_DESKTOP:-}" in
    KDE)  printf -v CMD  "%q  dolphin --select %q"  "$SDNAME"  "$FILE_OR_DIR_NAME";;
    XFCE) printf -v CMD  "%q  thunar %q"  "$SDNAME"  "$FILE_OR_DIR_NAME";;

    # Option --no-desktop is buggy in Caja version 1.20.2, the default file manager in Ubuntu MATE 18.04.
    # See the following bug report:
    #   https://github.com/mate-desktop/caja/issues/555
    # Unsetting environment variable DESKTOP_AUTOSTART_ID seems to work around the issue.
    MATE)

      if [ -d "$FILE_OR_DIR_NAME" ]; then
        NAME_TO_OPEN="$FILE_OR_DIR_NAME"
      else
        # Open the containing directory.
        NAME_TO_OPEN="$(dirname -- "$FILE_OR_DIR_NAME")"
      fi

      printf -v CMD  "%q  env --unset=DESKTOP_AUTOSTART_ID  caja --browser  --no-desktop -- %q"  "$SDNAME"  "$NAME_TO_OPEN";;
    *) ;;
  esac

fi

echo "$CMD"
eval "$CMD"
