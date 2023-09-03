#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.01"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
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


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  if is_tool_installed "$TOOL_NAME"; then
    return
  fi

  local ERR_MSG="Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager."

  if [[ $DEBIAN_PACKAGE_NAME != "" ]]; then
    ERR_MSG+=" For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
  fi

  abort "$ERR_MSG"
}

declare -r XSEL_TOOLNAME="xsel"


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2022-2023 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This script places the absolute path of the given filename in the X clipboard."
  echo "The specified file or directory must exist."
  echo
  echo "This tool is just a wrapper around '$XSEL_TOOLNAME', partly because I can never remember its command-line arguments."
  echo
  echo "Usage example:"
  echo "  $SCRIPT_NAME -- some/file/or/dir"
  echo "Afterwards, paste the copied text from the X clipboard into any application."
  echo
  echo "You can also specify one of the following options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Exit status: 0 means success, anything else is an error."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2022-2023 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


declare -r ERR_MSG_INVALID_ARGS="Invalid command-line arguments. Run this tool with the --help option for usage information."

if (( $# == 0 )); then
  abort "$ERR_MSG_INVALID_ARGS"
fi

case "$1" in
  --help)
    display_help
    exit $EXIT_CODE_SUCCESS;;
  --license)
    display_license
    exit $EXIT_CODE_SUCCESS;;
  --version)
    echo "$VERSION_NUMBER"
    exit $EXIT_CODE_SUCCESS;;
  --) shift;;
  -*) abort "Unknown option \"$1\".";;
esac

if (( $# != 1 )); then
  abort "$ERR_MSG_INVALID_ARGS"
fi

declare -r FILENAME="$1"

# Say you have a symbolic link "CurrentEmacsVersion" which points to "Emacs-29.1".
# If you ask to copy path "CurrentEmacsVersion/bin/emacs", you probably do not want
# to resolve the symbolic link and get "Emacs-29.1/bin/emacs" instead.
declare -r RESOLVE_LINKS=false

if $RESOLVE_LINKS; then

  ABS_FILENAME="$(readlink --canonicalize-existing --verbose -- "$FILENAME")"

  if [[ "$ABS_FILENAME" != "/" && -d "$ABS_FILENAME" ]]; then
    ABS_FILENAME+="/"
  fi

else

  # You would think that "realpath --no-symlinks ." should work, but it doesn't.
  # Something along the way is resolving any symbolic links in the current directory.
  if false; then

    ABS_FILENAME="$(realpath --no-symlinks -- "$FILENAME")"

    if [[ "$ABS_FILENAME" != "/" && -d "$ABS_FILENAME" ]]; then
      ABS_FILENAME+="/"
    fi

  else

    # Note that '-d' and '-e' below can get confused with paths like "/bin/..", where the a symlink
    # in the path traverses several directory levels.
    # The reason is that "/bin" is usually a symbolic link to "/usr/bin/",
    # so "/bin/.." ends up referring to "/usr/".
    # Bash' built-in -d and -e behave like external tools such as 'ls': they resolve symlinks as they go.
    #
    # This behaviour does not mach what 'cd -L' below does, and 'cd -L' is actually the default behaviour of 'cd'.
    # Bash' own tab completion does not resolve symlinks either, that is, it behaves like 'cd -L'.
    # So you can actually generate a path with tab completion which then fails when passed to 'ls'.
    #
    # I do not know yet what the best way would be to handle this inconsistency.
    # The way this script is coded at the moment means that ".." may cause trouble with symlinks,
    # but you can encounter this kind of trouble today with Bash' own tab completion and normal external commands.

    if [[ -d "$FILENAME" ]]; then

      PREV_DIR="$PWD"
      cd -L -- "$FILENAME"
      ABS_FILENAME="$PWD"
      cd -- "$PREV_DIR"

      if [[ "$ABS_FILENAME" != "/"  ]]; then
        ABS_FILENAME+="/"
      fi

    elif ! [[ -e "$FILENAME" ]]; then

      abort "File or directory does not exist: $FILENAME"

    elif ! [[ "$FILENAME" == */* ]]; then  # If the filename does not contain any '/' characters (directory separators).

      if [[ "$PWD" = "/" ]]; then
        ABS_FILENAME="/$FILENAME"
      else
        ABS_FILENAME="$PWD/$FILENAME"
      fi

    else

      # This only works if the path contains at least one '/'. That is why we checked for '/' characters above.
      DIRNAME="${FILENAME%/*}"

      # A filename like "/toplevel" would yield an empty string.
      if [[ $DIRNAME = "" ]]; then
        DIRNAME="/"
      fi

      # There must be no trailing '/' in the path. That is why we check beforehand if the path exists,
      # in which case it would be a directory, so it would have been handled above.
      BASENAME="${FILENAME##*/}"

      if false; then
        echo "DIRNAME : $DIRNAME"
        echo "BASENAME: $BASENAME"
      fi

      PREV_DIR="$PWD"
      cd -L -- "$DIRNAME"
      ABS_BASE_DIR="$PWD"
      cd -- "$PREV_DIR"

      if [[ "$ABS_BASE_DIR" = "/" ]]; then
        ABS_FILENAME="/$BASENAME"
      else
        ABS_FILENAME="$ABS_BASE_DIR/$BASENAME"
      fi

    fi

  fi

fi


# Just in case, check that the path we have come up with does exist.

if ! [[ -e "$ABS_FILENAME" ]]; then
  abort "The generated path \"$ABS_FILENAME\" does not exist. Directory components like '..' are known to cause problems with symlinks."
fi


verify_tool_is_installed "$XSEL_TOOLNAME" "xsel"

echo -n "$ABS_FILENAME" | "$XSEL_TOOLNAME" --input --clipboard

# Note that xsel forks and detaches from the terminal (if it is not just clearing the clipboard).
# xsel then waits indefinitely for other programs to retrieve the text it is holding,
# perhaps multiple times. When something else replaces or deletes the clipboard's contents,
# xsel automatically terminates.

echo "Path copied to the clipboard: $ABS_FILENAME"
