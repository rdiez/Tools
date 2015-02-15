#!/bin/bash

# RunBundledScriptAfterDelay.sh version 1.00
# Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3
#
# This tool runs a script with the given command-line arguments after a delay (see 'sleep').
# The script to run needs not be a full path, as this tool will change to the directory where
# it resides before attempting to run the script. Symbolic links are correctly resolved
# along the filepath used to run the tool.
#
# Example:
#
#   /somewhere/RunBundledScriptAfterDelay.sh  0.5s  ./test.sh a b c
#
# That example is equivalent to:
#
#   sleep 0.5s
#   cd "/somewhere"
#   ./test.sh a b c
#
# The main usage scenario is when running a user-defined script from KDE's autostart with a delay.
# If the script does not use a configuration file under the user's home directory, but expects
# to find its data where it is located, this tool helps, as KDE does not properly resolve
# symlinks when running an autostart entry.
#
# KDE autostart HINT: When adding to KDE autostart, leave option "Create as symlink" ticked,
#                     otherwise this script gets copied (!) to some obscure KDE folder, and then the
#                     copy becomes easily stale.

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


find_where_this_script_is ()
{
  if ! is_var_set BASH_SOURCE; then
    # This happens when feeding the script to bash over an stdin redirection.
    abort "Cannot find out in which directory this script resides: built-in variable BASH_SOURCE is not set."
  fi

  local SOURCE="${BASH_SOURCE[0]}"

  local TRACE=false

  while [ -h "$SOURCE" ]; do  # Resolve $SOURCE until the file is no longer a symlink.
    TARGET="$(readlink "$SOURCE")"
    if [[ $SOURCE == /* ]]; then
      if $TRACE; then
        echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
      fi
      SOURCE="$TARGET"
    else
      local DIR1="$( dirname "$SOURCE" )"
      if $TRACE; then
        echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$DIR1')"
      fi
      SOURCE="$DIR1/$TARGET"  # If $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located.
    fi
  done

  if $TRACE; then
    echo "SOURCE is '$SOURCE'"
  fi

  local DIR2="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  if $TRACE; then
    local RDIR="$( dirname "$SOURCE" )"
    if [ "$DIR2" != "$RDIR" ]; then
      echo "DIR2 '$RDIR' resolves to '$DIR2'"
    fi
  fi

  DIR_WHERE_THIS_SCRIPT_IS="$DIR2"
}


if [ $# -lt 2 ]; then
  abort "Invalid number of command-line arguments. See this tool's source code for more information."
fi


find_where_this_script_is
# echo "DIR_WHERE_THIS_SCRIPT_IS: $DIR_WHERE_THIS_SCRIPT_IS"
cd "$DIR_WHERE_THIS_SCRIPT_IS"

SLEEP_ARG="$1"

sleep "$SLEEP_ARG"

shift

# I am not certail what execution method is best. The 'exec' method does not work for certain bash-built-in commands like 'type'.
if true; then
  printf -v QUOTED_ARGS "%q " "$@"
  eval "$QUOTED_ARGS"
else
  exec "$@"
fi
