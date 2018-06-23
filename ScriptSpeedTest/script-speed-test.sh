#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

# set -x  # Enable tracing of this script file.


test_code ()
{
  # Place here the script code you want to test. For example, this just
  # runs 'sed' to print and discard its version number:

  sed --version >/dev/null
}


read_uptime ()
{
  local PROC_UPTIME_CONTENTS
  PROC_UPTIME_CONTENTS="$(</proc/uptime)"

  local PROC_UPTIME_COMPONENTS
  IFS=$' \t' read -r -a PROC_UPTIME_COMPONENTS <<< "$PROC_UPTIME_CONTENTS"

  UPTIME=${PROC_UPTIME_COMPONENTS[0]}
}


declare -i ITERATION_COUNT=1000

echo "Running $ITERATION_COUNT iterations..."

read_uptime
SYSTEM_UPTIME_BEGIN="$UPTIME"

COUNTER=0
while [ $COUNTER -lt $ITERATION_COUNT ]; do
  COUNTER=$(( COUNTER + 1 ))
  test_code
done

read_uptime
SYSTEM_UPTIME_END="$UPTIME"

# Tool 'bc' does not print the leading zero, so that is why there is an "if" statement in the expression below.
ELAPSED_TIME="$(bc <<< "scale=2; result = $SYSTEM_UPTIME_END - $SYSTEM_UPTIME_BEGIN; if (result < 1 ) print 0; result")"

echo "Finished $ITERATION_COUNT iterations in $ELAPSED_TIME s."
