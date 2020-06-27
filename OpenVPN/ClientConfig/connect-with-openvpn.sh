#!/bin/bash

# Script version 1.20
#
# This scripts uses 'sudo', so you will probably be prompted for a password.
#
# In order to terminate the VPN connection, press Ctrl+C (which sends SIGINT),
# or close the terminal window (which sends SIGHUP).
# A clean-up handler will be executed upon receiving these signals, see
# the script source code below.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
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
# Note that the maximum length of a network interface name is severely limited.
declare -r INTERFACE_NAME="OpenVpnCliTap"


# I am confused about whether "openvpn --rmtun" needs root privileges or not.
#
# Note that you can check with command "ip link" whether the TAP appears in the interface list.
#
# With sudo:
#   $ sudo openvpn  --rmtun  --dev-type "tap"  --dev OpenVpnCliTap
#   Sat Jun 27 21:53:09 2020 TUN/TAP device OpenVpnCliTap opened
#   Sat Jun 27 21:53:09 2020 Persist state set to: OFF
#
# Without sudo:
#   $ openvpn  --rmtun  --dev-type "tap"  --dev OpenVpnCliTap
#   Sat Jun 27 21:49:43 2020 TUN/TAP device OpenVpnCliTap opened
#   Sat Jun 27 21:49:43 2020 Note: Cannot set tx queue length on OpenVpnCliTap: Operation not permitted (errno=1)
#   Sat Jun 27 21:49:43 2020 Persist state set to: OFF
#
# Note that the variant without sudo is still able to set the "persist state" to off, which seems
# to trigger the deletion of the TAP.
# There is a warning before that log message about not being able to set the tx queue length,
# but that probably does not matter, because we will be removing the TAP anyway.
# I checked with "ip link" afterwards, and the TAP was no longer there.
# Note that equivalent command "sudo tunctl -d OpenVpnCliTap" does need root provileges (?).
# Whether the TAP is owned by root, or by the current user, seems to make no difference.
#
# Therefore, I am now testing without sudo. The advantage is that, if the VPN session lasts more than 15 minutes,
# you will not be prompted for the sudo password anymore in order to remove the TAP after quitting OpenVPN.
# You could of course amend /etc/sudoers to prevent such password prompts altogether.
#
# Beware that trying to delete a non-existent TAP does not yield a good error message,
# only confusing warnings. In the end, it looks like setting the "persist state" to off
# on a non-existing TAP actually succeeds (!).
# Command "sudo tunctl -d tap-999", where tap-999 does not exist, has the same issue.
# Sometimes I wonder how the Linux Kernel and its tools can be of such low quality.

printf -v REMOVE_INTERFACE_CMD  "openvpn  --rmtun  --dev-type \"tap\"  --dev %q"  "$INTERFACE_NAME"


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
  ERR_MSG+="$REMOVE_INTERFACE_CMD"

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

CMD="sudo openvpn"

quote_and_append_args  CMD  "--mktun"

quote_and_append_args  CMD  "--dev-type" "tap"

quote_and_append_args  CMD  "--dev" "$INTERFACE_NAME"

if true; then

  # Set the TAP's owner and group to ours.
  # This step is actually not necessary. I wonder whether doing it improves security in any way.
  #
  # The TAP's owner and group can be queried on an existing TAP like this:
  #  $ cat  /sys/class/net/OpenVpnCliTap/owner
  #  $ cat  /sys/class/net/OpenVpnCliTap/group

  # OpenVPN does not take user or group IDs, so we must pass names.
  MY_NAME="$(id --name --user)"    # Should be the same as Bash variable USER.
  MY_GROUP="$(id --name --group)"  # I haven't found an equivalent Bash variable for this.

  quote_and_append_args  CMD  "--user"  "$MY_NAME"
  quote_and_append_args  CMD  "--group" "$MY_GROUP"

fi

echo "$CMD"
eval "$CMD"

echo


# Now that we have created the TAP, install a handler to automatically remove it in the end.
#
# OpenVPN does not seem to kill itself with SIGINT after cleaning up upon the reception of a SIGINT signal.
# Instead, it quits with a exit code of 0 (as of version OpenVPN 2.4.4). Killing itself with SIGINT in such scenario
# is actually the recommended practice, so I expected that OpenVPN will be modified accordingly in the future.
# SIGTERM shows the same behaviour as SIGINT.
# SIGHUP is similar, only that the exit code is 1 instead of 0.
#
# For the time being, OpenVPN's behaviour above means that this script will not terminate upon receiving SIGINT.
# Bash does receive SIGINT too, but it waits for the child process first. Because child process did not terminate
# due to a signal, Bash assumes that the signal was a normal aspect of the program's working, so it does not quit.
#
# But we should not rely on this behaviour. Therefore, I am using an EXIT trap.
# On Bash, EXIT traps are executed even after receiving a signal.

trap "exit_cleanup" EXIT


# Disable IPv6 on our tunnel.
# You may want to keep IPv6 functionality though.

if true; then

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

fi

echo

printf -v CMD "sudo openvpn  --config %q"  "$CONFIG_FILENAME"

echo "Starting OpenVPN..."

echo "$CMD"

set +o errexit
eval "$CMD"
OPENVPN_EXIT_CODE="$?"
set -o errexit

# Note that, if a future version of OpenVPN dies upon receiving SIGINT (as it should, see the information
# about this above), then Bash will not carry on here, but will also die from SIGINT too.

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
# quit beforehand if OPENVPN_EXIT_CODE indicated an OpenVPN error.
# But then, beware that after receiving a signal like SIGINT, execution may
# never reach this point, see further above for details.
