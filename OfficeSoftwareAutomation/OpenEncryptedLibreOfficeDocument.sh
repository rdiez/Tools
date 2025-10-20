#!/bin/bash

# This script is designed to be used with RDiezDocUtils.vbs ,
# see that file for more information.

# Copyright (c) 2025 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


# ------ Entry Point (only by convention) ------

if (( $# != 2 )); then
  abort "Invalid command-line arguments. Please specify <document filename>, <password>."
fi

declare -r DOC_FILENAME="$1"

# It would be more secure to specify a file descriptor to read the password from.
# However, we will pass the password to LibreOffice in clear text on the command line anyway,
# so anybody who can list process arguments can snoop the password.
# Note that, on Linux, it is rather common that all user accounts can list all process arguments.
# Therefore, your password is probably not very safe.
# See also:
#   Bug 42647 - command line option to specify password
#   https://bugs.documentfoundation.org/show_bug.cgi?id=42647
declare -r PASSWORD="$2"

echo "Starting LibreOffice..."

CMD="soffice"

# If the filename or password have characters which collide with LibreOffice's BASIC syntax,
# like '(' or ',', this will break. The safest way would be to improve the code
# in this script, and in the LibreOffice side too, in order to hex-encode these strings.

MACRO_CMD="macro:///standard.RDiezDocUtils.OpenPasswordProtectedFile(\"${DOC_FILENAME}\", \"${PASSWORD}\")"

CMD+=" ${MACRO_CMD@Q}"

# Only print the command for troubleshooting purposes, as the password is visible in clear text.
if false; then
  echo "$CMD"
fi

if true; then

  # The '&' is in case LibreOffice is not already running. Without it, the script would wait for it to finish.
  #
  # The trouble is, '&' tends to break this script when called from Emacs, for example,
  # see the alternative with StartDetached.sh below.

  eval "$CMD" &

else

  # Warning: If you choose this method, the password will land in syslog.
  #
  # Script StartDetached.sh is in the same Git repository as this script.

  eval "StartDetached.sh --log-tag-name=${SCRIPT_NAME@Q} -- $CMD"

fi

echo "Finished starting LibreOffice."
