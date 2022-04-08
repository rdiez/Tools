#!/bin/bash

# I tend to have a collection of local software compiled from source.
# This software is not always on the PATH, because I normally use the versions
# that come pre-packaged with the Linux distribution. But sometimes
# I want to use the alternative versions I built manually.
# This is the script I use to add such software to the PATH on demand.
#
# Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3


# This file must be sourced from Bash with '.' or 'source', so it does not need to be marked as executable.
#
# The main reason why the shebang ("#!/bin/bash") is present at the top is to help with ShellCheck.

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  echo >&2
  echo "Error: The script \"${BASH_SOURCE[0]##*/}\" must be sourced." >&2
  exit 1
fi


# The long, strange routine name is to prevent name collisions with the sourcing (parent) script.

stalstp_add_to_path ()
{
  local -r DIR_NAME="$1"

  local DIR_NAME_ABS  # Split declaration from assignment so that $? works.

  DIR_NAME_ABS="$(readlink --canonicalize-existing --verbose -- "$DIR_NAME")"

  local -i EXIT_CODE="$?"

  if (( EXIT_CODE != 0 )); then
    echo >&2
    echo "Error in \"${BASH_SOURCE[0]##*/}\": Directory does not exist: $DIR_NAME" >&2
    exit 1
  fi

  # You would normally do:
  #   PATH="$DIR_NAME_ABS:$PATH"
  # But the expression below handles the case where PATH is not defined (which is actually very rare).

  PATH="$DIR_NAME_ABS${PATH:+:${PATH}}"
}


if false; then
  echo "PATH beforehand: $PATH"
fi

if false; then
  echo "${BASH_SOURCE[0]##*/}: Adding local software to the PATH..."
fi


stalstp_add_to_path "$HOME/rdiez/utils"


declare STALSTP_LOCAL_SOFTWARE="$HOME/rdiez/LocalSoftware"

# Why GNU Make version 4.3:
#   A change to how pipe waiting works promises to speed up parallel kernel builds - always a kernel developer's favorite
#   workload - but can also trigger a bug with old versions of GNU Make.
#   https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=0ddad21d3e99
stalstp_add_to_path "$STALSTP_LOCAL_SOFTWARE/GnuMake/CurrentGnuMake/bin"

stalstp_add_to_path "$STALSTP_LOCAL_SOFTWARE/Autotools/CurrentAutotools/bin"
stalstp_add_to_path "$STALSTP_LOCAL_SOFTWARE/HtmlTidy/CurrentHtmlTidy/bin"

unset -v STALSTP_LOCAL_SOFTWARE


unset -f stalstp_add_to_path

if false; then
  echo "PATH afterwards: $PATH"
fi

echo "${BASH_SOURCE[0]##*/}: The local software was added to the PATH."
