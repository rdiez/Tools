#!/bin/bash

# There are 2 approaches to registering VPN client IP addresses for Proxy ARP:
#
# - Register all possible IP addresses at once at the beginning, and unregister them at the end.
#   This is what this script does.
#
#   The main disadvantage is that, if the network interface goes down, all registrations will be lost.
#   The OpenVPN server will not notice, though, so you will have to manually restart the OpenVPN server,
#   in order for this script to reregister the IP addresses again.
#
#   It is possible to set up a hook, so that the OpenVPN server is torn down when the corresponding
#   network interface stops, consult your system's documentation for details.
#   This may always be a good idea anyway. It turns out that the OpenVPN server does not realise
#   that the interface it needs is down, even if you have used configuration directive 'local' to bind
#   the server to a particular static IP address associated to one network interface. Apparently,
#   the listening UDP socket will not be affected, and the OpenVPN server will continue running,
#   even if it can no longer serve any clients.
#
# - Register and unregister each IP address upon VPN client connection and disconnection,
#   see configuration directives 'client-connect' and 'client-disconnect'.
#
#   The main disadvantage is that the OpenVPN server needs to run scripts whenever VPN clients come and go.
#   The performance impact probably do not really matter, but such scripts need elevated network privileges
#   and the OpenVPN server usually drops most privileges on start-up. Therefore, the ability
#   to run such scripts may constitute an increased security risk.
#
# In any case, configuring Proxy ARP here is a lot of work. The OpenVPN server should do this
# kind of tasks automatically for us.
#
# Copyright (c) 2023 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit 1
}


# ------- Entry point -------

echo "Running $SCRIPT_NAME ..."

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments."
fi

declare -r ADD_OR_REMOVE="$1"

case "$ADD_OR_REMOVE" in
    add)    declare -r SHOULD_ADD=true;;
    remove) declare -r SHOULD_ADD=false;;
  *) abort "Invalid command-line argument \"$ADD_OR_REMOVE\".";;
esac

# You will need to adjust the nework interface name below to match your system.
# If you are using a virtual network bridge, you cannot use the name of the real
# (hardware) interface here. Instead, you need to specify the name of the virtual interface that
# the bridge automatically created. That virtual interface has the same name as the bridge itself.
declare -r NETWORK_INTERFACE="enp1s0"

# You will also have to modify the IP addresses below, and perhaps the whole loop,
# if your IP address range extends to more bytes than the last one.
declare -r -i FIRST_CLIENT_IP_ADDRESS=82
declare -r -i LAST_CLIENT_IP_ADDRESS=86

for (( INDEX = FIRST_CLIENT_IP_ADDRESS ; INDEX <= LAST_CLIENT_IP_ADDRESS; ++INDEX )); do

  if $SHOULD_ADD; then

    # Register all possible VPN client IP addresses with the same MAC address as the network interface.
    # An alternative command would be: ip neigh add proxy ADDRESS dev NAME
    printf -v CMD \
           "arp  -i %q  -Ds %q  %q  pub" \
           "$NETWORK_INTERFACE" \
           "192.168.1.$INDEX" \
           "$NETWORK_INTERFACE"
  else

    # When removing the ARP entries, you may get the following error
    # if the IP address was not registered for Proxy ARP:
    #   "No ARP entry for 192.168.1.xxx"
    # The exit code will then be non-zero, so this script will stop.
    # We could ignore such errors, but I think it is better to let this script fail.
    # This way, the sysadmin will notice any eventual problems, because all IP addresses
    # are registered at the beginning, unregistering them should not normally fail.
    printf -v CMD \
           "arp  -i %q  -d %q" \
           "$NETWORK_INTERFACE" \
           "192.168.1.$INDEX"
 fi

  echo "$CMD"
  eval "$CMD"

done

echo "Finished running $SCRIPT_NAME ."
