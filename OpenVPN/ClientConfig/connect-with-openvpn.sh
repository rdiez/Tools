#!/bin/bash

# Script version 1.00 .
#
# This scripts uses 'sudo', so you will probably be prompted for a password.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


exit_cleanup ()
{
  echo

  echo "Removing network interface $INTERFACE_NAME ... "

  echo "$REMOVE_INTERFACE_CMD"
  eval "$REMOVE_INTERFACE_CMD"

  echo

  echo "OpenVPN connection terminated."
}


# ------- Entry point -------

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. Please specify only one argument with the OpenVPN configuration filename."
fi


declare -r CONFIG_FILENAME="$1"

# This interface name must match option 'dev' in the OpenVPN client configuration file.
declare -r INTERFACE_NAME="OpenVpnCliTap"


printf -v REMOVE_INTERFACE_CMD  "sudo openvpn  --rmtun  --dev-type \"tap\"  --dev %q"  "$INTERFACE_NAME"


# Check whether the TAP interface already exists.
#
# There are several ways to check whether a network interface exists:
# - Parse pseudofile /proc/net/dev
# - Check for the existence of directory (or a symbolic link to a subdirectory) under /sys/class/net .
# - Parse the output of command:  ip -oneline -brief link show
# - Check if this command fails:  ip -oneline -brief link show <interface name>

echo "Checking whether network interface $INTERFACE_NAME already  exists..."

printf -v CMD  "ip -oneline -brief link show %q"  "$INTERFACE_NAME"

echo "$CMD"

set +o errexit
eval "$CMD"
IP_EXIT_CODE="$?"
set -o errexit

if (( IP_EXIT_CODE == 0 )); then

  ERR_MSG="Network interface $INTERFACE_NAME already exists. This is an indication that something went wrong the last time around."
  ERR_MSG+=$'\n'
  ERR_MSG+="You can manually remove that network interface with the following command:"
  ERR_MSG+=$'\n'
  # 'sudo' does not seem necessary in order to remove the network interface.
  ERR_MSG+="$REMOVE_INTERFACE_CMD"

  abort "$ERR_MSG"

fi


# OpenVPN does not seem to kill itself with SIGINT after cleaning up upon the reception of a SIGINT signal.
# Instead, it quits with a exit code of 0 (as of version OpenVPN 2.4.4). Killing itself with SIGINT in such scenario
# is actually the recommended practice, so I expected that OpenVPN will be modified accordingly in the future.
#
# For the time being, the behaviour above means that this script will not terminate upon receiving SIGINT,
# so we could clean up with normal code. But we should not rely on this. Therefore, I am using an EXIT trap.
# On Bash, EXIT traps are executed even after receiving a signal.

trap "exit_cleanup" EXIT


# This pause is only for test purposes.
if false; then
  read -r -p "Waiting for ENTER..."
fi

echo

echo "Creating network interface $INTERFACE_NAME ... "

# We could use here options '--user' and '--group' to set the tunnel ownership to the current user.
printf -v CMD  "sudo openvpn  --mktun  --dev-type \"tap\"  --dev %q"  "$INTERFACE_NAME"

echo "$CMD"
eval "$CMD"

echo

# Disable IPv6 on our tunnel.
# You may want to keep IPv6 functionality though.

echo "Disabling IPv6 on network interface $INTERFACE_NAME ... "

if false; then
  echo "Previous state of disable_ipv6:"
  sysctl "net.ipv6.conf.$INTERFACE_NAME.disable_ipv6"
fi

printf -v CMD  "sysctl --quiet --write %q"  "net.ipv6.conf.$INTERFACE_NAME.disable_ipv6=1"

echo "$CMD"
eval "$CMD"

if false; then
  echo "Current state of disable_ipv6:"
  sysctl "net.ipv6.conf.$INTERFACE_NAME.disable_ipv6"
fi


echo

printf -v CMD "sudo openvpn  --config %q"  "$CONFIG_FILENAME"

echo "Starting OpenVPN..."

echo "$CMD"

set +o errexit
eval "$CMD"
OPENVPN_EXIT_CODE="$?"
set -o errexit

echo "OpenVPN exit code: $OPENVPN_EXIT_CODE"


# You will probably get this error message at the end of the OpenVPN log:
#
#   Closing TUN/TAP interface
#   /sbin/ip addr del dev OpenVpnCliTap 192.168.100.121/24
#   RTNETLINK answers: Operation not permitted
#
# The reason is that OpenVPN has not created the TAP, as it normally does, but this script has,
# and the permissions on the TAP are probably not quite right. After OpenVPN downgrades
# its privileges to nobody and nogroup, it can no longer modify the TAP.
# I have investigated a little further, and this also happens if you run OpenVPN directly with sudo
# and without this script, at least with OpenVPN 2.4.4 on Ubuntu 18.04. So it seems
# to be a shortcoming in OpenVPN. However, if this gets fixed, we may need to set the TAP
# permissions accordingly when using this script.
#
# For the time being, just ignore the error message above.


# At this point, the code in the EXIT trap installed above will be executed.
# If we wanted to do further normal processing here, we should
# quit if OPENVPN_EXIT_CODE indicated an OpenVPN error.
