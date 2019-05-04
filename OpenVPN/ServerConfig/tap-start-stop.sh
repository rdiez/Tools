#!/bin/bash

# Setting up the network TAP device with this script before running OpenVNP is actually a kludge.
# Such network devices should be prepared somewhere else upon boot, and not when OpenVPN starts.
#
# The trouble is, each Linux distribution does this in a different way. In Ubuntu 18.04 there is
# the Netplan layer, which can delegate to systemd or to NetworkManager.
# It is difficult to write a generic solution.
#
# I have not managed to find out yet how to create a persistent TAP interface with
# Ubuntu 18.04's Netplan.

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


declare -r BRIDGE="br0"

declare -r TAP="OpenVpnSrvTap"

declare -r ETH_INTERFACE="enp0s7"


start_tap ()
{
  echo "Starting the TAP..."

  local CMD


  # Check whether the TAP interface already exists.
  #
  # There are several ways to check whether a network interface exists:
  # - Parse pseudofile /proc/net/dev
  # - Check for the existence of directory (or a symbolic link to a subdirectory) under /sys/class/net .
  # - Parse the output of command:  ip -oneline -brief link show
  # - Check if this command fails:  ip -oneline -brief link show <interface name>

  echo "Checking whether network interface $TAP already  exists..."

  printf -v CMD  "ip -oneline -brief link show %q"  "$TAP"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  IP_EXIT_CODE="$?"
  set -o errexit

  if (( IP_EXIT_CODE == 0 )); then

    ERR_MSG="Network interface $TAP already exists. This is an indication that something went wrong the last time around."
    ERR_MSG+=$'\n'
    ERR_MSG+="You can manually remove that network interface with the following command:"
    ERR_MSG+=$'\n'
    # 'sudo' does not seem necessary in order to remove the network interface.
    ERR_MSG+="$REMOVE_TAP_CMD"

    abort "$ERR_MSG"

  fi


  # OpenVPN should actually create the TAP device automatically.
  # But we may be using this script manually, without OpenVPN.

  printf -v CMD  "openvpn  --mktun  --dev-type \"tap\"  --dev %q"  "$TAP"
  echo "$CMD"
  eval "$CMD"

  printf -v CMD  "brctl addif %q %q"  "$BRIDGE" "$TAP"
  echo "$CMD"
  eval "$CMD"

  # Note that we are enabling here the promiscuous mode on the main Ethernet interface,
  # whether it was already enabled or not.  We are also leaving it enabled later on
  # when we stop the bridge. That should have an impact on performance.
  # Enabling the promiscuous mode should be done at system level beforehand. But it is not easy,
  # at least with Ubuntu 18.04. I need to research more.
  printf -v CMD  "ip link set  %q  promisc on"  "$ETH_INTERFACE"
  echo "$CMD"
  eval "$CMD"

  printf -v CMD  "ip link set  %q  promisc on"  "$TAP"
  echo "$CMD"
  eval "$CMD"

  # If we do not bring the TAP interface up, nothing will work,
  # but you will get no error messages at all (!).
  printf -v CMD  "ip link set  %q  up"  "$TAP"
  echo "$CMD"
  eval "$CMD"

  echo "TAP started."
}


stop_tap ()
{
  echo "Stopping the TAP..."

  local CMD

  # It is probably not necessary to bring the TAP interface down before deleting it.
  printf -v CMD  "ip link set  %q  down"  "$TAP"
  echo "$CMD"
  eval "$CMD"

  # This is not really necessary. Deleting the TAP seems to remove it automatically from the bridge.
  printf -v CMD  "brctl delif %q %q"  "$BRIDGE" "$TAP"
  echo "$CMD"
  eval "$CMD"

  # OpenVPN should actually delete the TAP device automatically.
  # But we may be using this script manually, without OpenVPN.
  echo "$REMOVE_TAP_CMD"
  eval "$REMOVE_TAP_CMD"

  echo "TAP stopped."
}


# ------- Entry point -------

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. This tools expects a single 'start' or 'stop' argument."
fi

declare -r OPERATION="$1"


printf -v REMOVE_TAP_CMD  "openvpn  --rmtun  --dev-type \"tap\"  --dev %q" "$TAP"

case "$OPERATION" in
  start) start_tap;;
  stop)  stop_tap;;
  *) abort "Invalid operation \"$OPERATION\".";;
esac
