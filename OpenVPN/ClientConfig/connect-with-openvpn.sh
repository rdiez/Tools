#!/bin/bash

# Script version 1.30
#
# This script must run with root privileges, so make sure to place it,
# toghether with the .ovpn connection file, somewhere where only root has read and write access.
#
# In order to terminate the VPN connection, press Ctrl+C (which sends SIGINT),
# or close the terminal window (which sends SIGHUP).
# Note that closing the terminal window (SIGHUP) may not work, depending on how your system
# (pty and/or terminal emulator) send signals to processes that may be running as another user (like root).
#
# Copyright (c) 2019-2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


quote_and_append_args ()
{
  local -n VAR="$1"
  shift

  local STR

  # Shell-quote all arguments before joining them into a single string.
  printf -v STR  "%q "  "$@"

  # Remove the last character, which is one space too much.
  STR="${STR::-1}"

  if [ -z "$VAR" ]; then
    VAR="$STR"
  else
    VAR+="  $STR"
  fi
}


exit_cleanup ()
{
  # Cleaning up is performed on a best-effort basis, and if something fails,
  # it should not prevent other clean-up steps.
  #
  # If the user closes the console, this script will receive SIGHUP,
  # and this routine will run. But then writing to stdout will fail,
  # because closing the console means that the terminal (pty) underneath will also disappear.
  set +o errexit

  echo

  echo "Removing network interface $INTERFACE_NAME ..."

  echo "$REMOVE_INTERFACE_CMD"

  eval "$REMOVE_INTERFACE_CMD"
  local -r REMOVE_INTERFACE_EXIT_CODE="$?"

  echo "Remove interface exit code: $REMOVE_INTERFACE_EXIT_CODE"

  echo

  echo "OpenVPN connection terminated."
}


# ------- Entry point -------

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. Please specify only one argument with the OpenVPN configuration filename."
fi


declare -r CONFIG_FILENAME="$1"


if (( EUID != 0 )); then
  abort "This script must run as root."
fi


# This interface name must match option 'dev' in the OpenVPN client configuration file.
# Note that the maximum length of a network interface name is severely limited.
declare -r INTERFACE_NAME="OpenVpnCliTap"

printf -v REMOVE_INTERFACE_CMD \
       "openvpn  --rmtun  --dev-type \"tap\"  --dev %q" \
       "$INTERFACE_NAME"


# Check whether the TAP interface already exists, as it might have been left behind the last time around.
# If we do not check beforehand, trying to create the TAP again will fail, and the user will not
# get an obvious error message about what s/he should do.
#
# There are several ways to check whether a network interface exists:
# - Parse pseudofile /proc/net/dev
# - Check for the existence of directory (or a symbolic link to a subdirectory) under /sys/class/net .
# - Parse the output of command:  ip -oneline -brief link show
# - Check if this command fails:  ip -oneline -brief link show <interface name>

echo "Checking whether network interface $INTERFACE_NAME already exists..."

printf -v CMD \
       "ip -oneline -brief link show %q" \
       "$INTERFACE_NAME"

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
  # I am not certain that "openvpn  --rmtun" needs sudo, but print it just in case.
  ERR_MSG+="  sudo $REMOVE_INTERFACE_CMD"
  ERR_MSG+=$'\n'
  ERR_MSG+="If that fails, try this command:"
  ERR_MSG+=$'\n'
  ERR_MSG+="  sudo ip link delete OpenVpnCliTap"

  abort "$ERR_MSG"

fi

# This pause is only for test purposes.
if false; then
  read -r -p "Waiting for ENTER..."
fi

echo

echo "Creating network interface $INTERFACE_NAME ... "

# In order to create/remove the TAP, we could use tool 'tunctl' from Ubuntu/Debian package 'uml-utilities'
# instead of "openvpn --mktun/--rmtun".
#
# After creation, you can get information about the TAP in this directory:
#   /sys/class/net/OpenVpnCliTap

CMD=""

quote_and_append_args  CMD "openvpn" "--mktun" "--dev-type" "tap" "--dev" "$INTERFACE_NAME"

if false; then

  abort "Now that this script runs as root, if you enable this code, check out how we can get the calling user's ID and group ID."

  # Set the TAP's owner and group to ours.
  # This step is actually not necessary. I wonder whether doing it improves security in any way.
  #
  # The TAP's owner and group can be queried on an existing TAP like this:
  #  $ cat  /sys/class/net/OpenVpnCliTap/owner
  #  $ cat  /sys/class/net/OpenVpnCliTap/group

  # OpenVPN does not take user or group IDs, so we must pass names.
  MY_NAME="$(id --name --user)"    # Should be the same as Bash variable USER.
  MY_GROUP="$(id --name --group)"  # I haven't found an equivalent Bash variable for this.

  quote_and_append_args  CMD  "--user"  "$MY_NAME"  "--group" "$MY_GROUP"

fi

echo "$CMD"
eval "$CMD"

echo


# Now that we have created the TAP, install a handler to automatically remove it in the end.
#
# OpenVPN does not seem to kill itself with SIGINT after cleaning up upon the reception of a SIGINT signal.
# Instead, it quits with a exit code of 0 (as of version OpenVPN 2.4.4). Killing itself with SIGINT in such scenario
# is actually the recommended practice, so I expected that OpenVPN will be modified accordingly in the future.
# This is what OpenVPN prints upon receiving SIGINT:
#   Wed Dec  9 21:01:50 2020 us=520915 SIGINT[hard,] received, process exiting
#
# SIGTERM shows the same behaviour as SIGINT.
#
# Note that SIGHUP is not supposed to terminate the OpenVPN client, but to reload the configuration.
# However, that will always fail, because OpenVPN drops privileges upon connecting, so it will not
# be able to change the IP adress, reconnect, or even to read the configuration file again.
# It may take a short while, but OpenVPN will eventually exit. Therefore, we do not have to
# translate SIGHUP into SIGINT in this script in order to make OpenVPN terminate.
#
# For the time being, OpenVPN's behaviour above means that this script will not automatically terminate upon receiving SIGINT.
# Bash does receive SIGINT too, but it waits for the child process first. Because child process did not terminate
# due to a signal, Bash assumes that the signal was a normal aspect of the program's working, so it does not quit.
#
# But we should not rely on this behaviour. Therefore, I am using an EXIT trap.
# On Bash, EXIT traps are executed even after receiving a signal.
#
# If OpenVPN's behaviour were correct, we could determine whether it had terminated upon receiving
# SIGINT, and then we would know whether the user terminated the connection,
# of it was lost unexpectely. In the latter case, we could then create a desktop notification
# to alert the user that the connection has been unexpectedly lost.
# We would have to handle SIGHUP in some other way though.

trap "exit_cleanup" EXIT


# Disable IPv6 on our tunnel.
# You may want to keep IPv6 functionality though.

if true; then

  echo "Disabling IPv6 on network interface $INTERFACE_NAME ... "

  if false; then
    echo "Previous state of disable_ipv6:"
    sysctl "net.ipv6.conf.$INTERFACE_NAME.disable_ipv6"
  fi

  printf -v CMD \
         "sysctl --quiet --write %q" \
         "net.ipv6.conf.$INTERFACE_NAME.disable_ipv6=1"

  echo "$CMD"
  eval "$CMD"

  if false; then
    echo "Current state of disable_ipv6:"
    sysctl "net.ipv6.conf.$INTERFACE_NAME.disable_ipv6"
  fi

fi


echo

printf -v CMD \
       "openvpn  --config %q" \
       "$CONFIG_FILENAME"

echo "Starting OpenVPN..."

echo "$CMD"

set +o errexit
eval "$CMD"
OPENVPN_EXIT_CODE="$?"
set -o errexit

# Note that, if a future version of OpenVPN dies upon receiving SIGINT (as it should, see the information
# about this above), then Bash will not carry on here, but will also die from SIGINT too.
# But we have installed an EXIT trap to deal with such cases anyway.

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


# At this point, the code in the EXIT trap installed above will be executed,
# even if no signal was received.
# If we wanted to do further normal processing here, we should
# quit beforehand if OPENVPN_EXIT_CODE indicated an OpenVPN error.
# But then, beware that after receiving a signal like SIGINT, execution may
# never reach this point, see further above for details.
