#!/bin/bash

# WaitForSignals.sh version 1.01
#
# This script waits for Unix signals to arrive.
#
# You can choose the action for each signal in the script source code below:
# - Print the received signal's number and name, and then exit.
# - Print the received signal's number and name, and then ignore it.
# - Silently ignore the signal.
# - Do not trap a signal at all (upon reception, the default response will then ensue).
#
# This script is mainly useful during development or troubleshooting of Linux processes.
#
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


trap_signals ()
{
  local FUNCTION_NAME="$1"
  shift

  local SIGNAL_NUMBER

  for SIGNAL_NUMBER ; do
    # shellcheck disable=SC2064
    trap  "$FUNCTION_NAME  $SIGNAL_NUMBER"  "$SIGNAL_NUMBER"
  done
}


trap_function ()
{
  local SIGNAL_NUMBER="$1"

  # If the designator is a name, "kill -l" will return its number, and viceversa.
  # Note that we are using Bash' internal 'kill' command, as the external one
  # does not know the real-time signals.
  local SIGNAL_NAME
  SIGNAL_NAME="$(kill -l "$SIGNAL_NUMBER")"

  local ACTION
  ACTION="${SIGNAL_ACTIONS[$SIGNAL_NUMBER]}"

  # We write a new-line character at the beginning because the parent process may be writing to the console at the moment,
  # so we want to try to start writing on a fresh line.

  case "$ACTION" in
    exit)   echo $'\n'"Script $0 with PID $$ exiting upon reception of signal $SIGNAL_NUMBER ($SIGNAL_NAME)."
            exit;;

    ignore) echo $'\n'"Script $0 with PID $$ is ignoring signal $SIGNAL_NUMBER ($SIGNAL_NAME).";;

    silently-ignore) : ;;

    *) abort $'\n'"Internal error: Process with PID $$ has received signal $SIGNAL_NUMBER ($SIGNAL_NAME), but the configured signal action \"$ACTION\" for this signal is invalid.";;
  esac
}


# ---------- Entry point ----------

# Numbers 1 to 31 are standard signals. Numbers 32 to 64 are POSIX real-time signals.
# However, glibc reserves signals 32 and 33, so they are usually not available to the user on Linux.
# I could not find a way to retrieve the maximum valid signal number. Command "getconf RTSIG_MAX"
# gets pretty close though.

declare -A SIGNAL_ACTIONS=()  # Associative array.

# Possible actions are:
# - exit
# - ignore
# - silently-ignore
#
# If a signal is not to be trapped at all (let the default behaviour ensue),
# do not place it in the associative array below (comment the corresponding line out).
# For example, signal SIGWINCH (28) tends to trigger when you resize your terminal window,
# and is therefore a good candidate to leave out, because its default response is
# normally to ignore it. However, this script ignores it (but prints a message), so that
# you get to see it.
#
# Some signals, like 9 (SIGKILL), cannot actually be trapped. Attempting to trap them
# will have no effect.

DEFAULT_ACTION="exit"

SIGNAL_ACTIONS[1]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[2]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[3]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[4]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[5]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[6]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[7]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[8]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[9]="$DEFAULT_ACTION"  # SIGKILL, cannot actually be trapped.
SIGNAL_ACTIONS[10]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[11]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[12]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[13]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[14]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[15]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[16]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[17]="silently-ignore"  # SIGCHLD, we need to ignore it because otherwise, when child process 'sleep' terminates, this scripts exits.
SIGNAL_ACTIONS[18]="$DEFAULT_ACTION"  # SIGCONT, counterpart from SIGSTOP, can be trapped.
SIGNAL_ACTIONS[19]="$DEFAULT_ACTION"  # SIGSTOP, cannot actually be trapped.
SIGNAL_ACTIONS[20]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[21]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[22]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[23]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[24]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[25]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[26]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[27]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[28]="ignore"  # SIGWINCH, a good candidate to ignore (or to not trap at all), see above for more information.
SIGNAL_ACTIONS[29]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[30]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[31]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[32]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[33]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[34]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[35]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[36]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[37]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[38]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[39]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[40]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[41]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[42]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[43]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[44]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[45]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[46]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[47]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[48]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[49]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[50]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[51]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[52]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[53]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[54]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[55]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[56]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[57]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[58]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[59]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[60]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[61]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[62]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[63]="$DEFAULT_ACTION"
SIGNAL_ACTIONS[64]="$DEFAULT_ACTION"


ELEM_COUNT="${#SIGNAL_ACTIONS[@]}"

if false; then
  echo "Trapped signal count: $ELEM_COUNT"
fi

if (( ELEM_COUNT < 1 )); then
  abort "There are no signals to trap."
fi

trap_signals  trap_function  "${!SIGNAL_ACTIONS[@]}"

echo "Script $0 with PID $$ is waiting for signals."


if false; then
  # Send ourselves a signal, useful for testing this script.
  TEST_SIGNAL_NUMBER="$(kill -l SIGINT)"
  kill -n "$TEST_SIGNAL_NUMBER" "$$"
fi


# Forever wait.
#
# We cannot sleep for a long time at once, because 'sleep' is usually an external command, and,
# while we are waiting for the 'sleep' child process to finish, we will not realise that
# a signal has arrived in the meantime.
#
# Note that Bash can load external commands, and its source code comes with a 'sleep' example
# to load that way, but building it is way too much hassle.
#
# The work-around implemented here is to sleep for short amounts of time, which does
# waste a little CPU time.
#
# Alternatively, you can probably create a pipe with 'mkfifo' and read from it,
# which should not waste any CPU time at all.

while true; do
  sleep 0.1s
done
