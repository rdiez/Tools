#!/bin/bash

# Version 1.03.
#
# This script opens a file explorer on the given file or directory.
#
# Which file explorer is started depends on the underlying operating system,
# but you can hard-code your choice below.
#
# I wrote this script because I often want to copy files from the current directory with the mouse,
# or I just want a standard OS file explorer window that shows the file I am currently editing in Emacs.
# Each operating system and desktop environment is different, so this script abstracts all differences
# and opens a file explorer that shows the given file or directory, with as much comfort as the
# underlying platform allows.
#
# Copyright (c) 2019-2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
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


# Check that the file or directory does exist.
#
# It is not clear whether all file managers display an error message if it does not.
# For example, in the case of 'Caja' (from the MATE Desktop), we cannot pass a filename,
# and the base directory may exist. If we do not check for existence, then the user
# may not realise (or realise too late) that the requested file does not exist.
# I do not think that such a behaviour is a good idea, so always check upfront.

if [ ! -e "$FILE_OR_DIR_NAME" ]; then
  abort "File or directory \"$FILE_OR_DIR_NAME\" does not exist."
fi


# You normally need to start the file manager process in the background (with StartDetached.sh or similar).
# Otherwise, if this is the first file manager window, most file managers do not terminate until
# the last window is gone, so the current console or process forever blocks.
declare -r SDNAME="StartDetached.sh"


if false; then

  # Here you can manually edit the code below and use the command you want.
  # But is normally best to use the automatic desktop environment detection logic below.

  if false; then

    verify_start_detached_is_installed

    printf -v CMD  "%q  nautilus --no-desktop --browser -- %q"  "$SDNAME"  "$FILE_OR_DIR_NAME"

  else

    # This uses the standard "xdg-open" tool.

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

    KDE)  # Dolphin's --select option behaves differently when a directory name ends with a slash:
          # - With a trailing '/', it opens the given directory.
          #   This is the behaviour we have chosen here to implement.
          # - Without a trailing '/, it opens the parent directory and selects the given directory.
          # That applies tot he current directory too, so "." and "./" behave differenty.

          if [ -d "$FILE_OR_DIR_NAME" ]; then
            # This includes the special case of the root directory '/'.
            if str_ends_with "$FILE_OR_DIR_NAME" "/"; then
              NAME_TO_OPEN="$FILE_OR_DIR_NAME"
            else
              NAME_TO_OPEN="${FILE_OR_DIR_NAME}/"
            fi
          else
            NAME_TO_OPEN="$FILE_OR_DIR_NAME"
          fi

          printf -v CMD  "%q  dolphin --select %q"  "$SDNAME"  "$NAME_TO_OPEN"
          ;;

    XFCE)  # As of Thunar version 1.8.14 (Xfce 4.14), you cannot pass a filename, because it
           # will then open it with the standard tool associated to that file type (or the standard text editor).

           if [ -d "$FILE_OR_DIR_NAME" ]; then
             NAME_TO_OPEN="$FILE_OR_DIR_NAME"
           else
             # Thunar has no equivalent to "--select", so just open the containing directory.
             NAME_TO_OPEN="$(dirname -- "$FILE_OR_DIR_NAME")"
           fi

           printf -v CMD  "%q  thunar %q"  "$SDNAME"  "$NAME_TO_OPEN"
           ;;

    MATE)

      # MATE caja 1.24.0 displays an error if the filename passed is a normal file,
      # so we always to have to pass a directory.

      if [ -d "$FILE_OR_DIR_NAME" ]; then
        NAME_TO_OPEN="$FILE_OR_DIR_NAME"
      else
        # Caja has no equivalent to "--select", so just open the containing directory.
        NAME_TO_OPEN="$(dirname -- "$FILE_OR_DIR_NAME")"
      fi

      # Option --no-desktop is buggy in Caja version 1.20.2, the default file manager in Ubuntu MATE 18.04.
      # See the following bug report:
      #   https://github.com/mate-desktop/caja/issues/555
      # Unsetting environment variable DESKTOP_AUTOSTART_ID seems to work around the issue.

      printf -v CMD  "%q  env --unset=DESKTOP_AUTOSTART_ID  caja --browser  --no-desktop -- %q"  "$SDNAME"  "$NAME_TO_OPEN"
      ;;

    *) abort "Could not determine the current desktop environment, please check environment variable XDG_CURRENT_DESKTOP.";;
  esac

fi

echo "$CMD"
eval "$CMD"
