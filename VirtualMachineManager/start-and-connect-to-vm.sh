#!/bin/bash

# start-and-connect-to-vm.sh, version 1.00.
#
# This script starts the given Linux libvirt virtual machine, if not already running,
# and opens a graphical console to it with virt-manager.
#
# Usage:
#
#  start-and-connect-to-vm.sh  NAME|ID|UUID
#
# This script is hard-coded to connect to the local qemu system.
#
# Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r EXIT_CODE_ERROR=1

declare -r CONNECTION_URI="qemu:///system"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments."
fi

VM_ID="$1"


printf -v CONNECTION_URI_QUOTED  "%q"  "$CONNECTION_URI"
printf -v VM_ID_QUOTED  "%q"  "$VM_ID"


# Set the LANG to a default value, so that the status you get is "running", etc. in English,
# and not some localised/translated version.
#
# By the way, we are parsing a string meant for the user, which is not very robust.
# But there does not seem to be any other easy way to query the status from a shell script.

echo "Checking whether virtual machine \"$VM_ID\" is running..."

printf -v CMD  "env LANG=C  virsh  --connect %q  domstate %q" "$CONNECTION_URI_QUOTED"  "$VM_ID_QUOTED"

echo "$CMD"
STATUS="$(eval "$CMD")"

case "$STATUS" in
  "running")  IS_RUNNING=true;;
  "shut off") IS_RUNNING=false;;
  *) abort "Unexepected status of \"$STATUS\".";;
esac


if $IS_RUNNING; then
  echo "Virtual machine \"$VM_ID\" is already running."
else
  echo "Starting virtual machine \"$VM_ID\"..."
  printf -v CMD  "virsh  --connect %q  start %q"  "$CONNECTION_URI_QUOTED"  "$VM_ID_QUOTED"
  echo "$CMD"
  eval "$CMD"
fi


# If we open the graphical console like this:
#
#  virt-viewer --reconnect --zoom=100  "$VM_ID"
#
# Then we can control the zoom level and other things. But then the graphical console
# is missing the "Virtual Machine" menu with useful options like creating a vm snapshot.
#
# Unfortunately, I found the following inconveniences with "virt-manager --show-domain-console":
# 1) You cannot pass any flags to the viewer like --zoom .
# 2) I would like to automatically do a "View", "Resize to VM" when the log-on manager GUI starts
#    in a booting virtual machine. At the moment, I have to manually resize the graphical console
#    with the mouse, or choose that menu option manually, when the guest OS log-on screen appears.
# 3) If I shutdown the virtual machine, the graphical console should automatically close.
#    By the way, that is the behaviour of alternative tool virt-viewer, if you do not specify
#    the '--reconnect' option.
# 4) If I close the graphical console, the virtual machine "inside" is automatically shut down.
#
# If you do not specify --no-fork, virt-manager will immediately fork and return a success exit code
# without doing a minimum of error checking, like whether the virtual machine name exists.
# However, specifying --no-fork blocks the caller, which is often unwanted.
# If this bugs you, I would suggest using --no-fork together with my StartDetached.sh script,
# which redirects stdout/stderr to the system log.

echo "Opening the graphical console of virtual machine \"$VM_ID\"..."

printf -v CMD  "virt-manager  --no-fork  --connect=%q  --show-domain-console %q"  "$CONNECTION_URI_QUOTED"  "$VM_ID_QUOTED"
echo "$CMD"
eval "$CMD"

echo "The graphical console of virtual machine \"$VM_ID\" was closed."
