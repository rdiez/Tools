#!/bin/bash

# takeownership.sh version 1.00
#
# Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3
#
# This script is a convenient shortcut for the following commands:
#
# 1) If a filename is a regular file:
#
#      sudo chown "$SUDO_USER"  "filename" ...
#      sudo chgrp "$SUDO_GROUP" "filename" ...
#
#    But note that the commands above do not actually work, as we need to take $SUDO_USER
#    after 'sudo' has run (and not before), and $SUDO_GROUP does not actually exist.
#    This script does it properly though.
#
# 2) If a filename is a directory:
#
#    Same commands as above with option "--recursive".
#
# Note that "takeownership.sh dir" has the same effect as "takeownership.sh dir/". That is,
# appending a '/' to a directory name has no effect.

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if [ $# -lt 1 ]; then
  abort "You need to specify at least a filename."
fi


# Be careful not to take the current value of the $SUDO_xx variables (if they exist), as tool 'sudo'
# may set it to a different value.

# Warning: The following quoting method does not work for arguments like "5'6", use 'printf -v' instead:
#  QUOTED_ARGS="$(printf "%q " "$@")"
printf -v QUOTED_ARGS "%q " "$@"

CMD="chown --recursive \"\$SUDO_UID:\$SUDO_GID\" $QUOTED_ARGS"

sudo bash -c "$CMD"
