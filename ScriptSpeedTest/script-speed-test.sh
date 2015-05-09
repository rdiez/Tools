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


ITERATION_COUNT=1000

echo "Running $ITERATION_COUNT iterations..."

PROC_UPTIME_CONTENTS="$(</proc/uptime)"
PROC_UPTIME_COMPONENTS=($PROC_UPTIME_CONTENTS)
SYSTEM_UPTIME_BEGIN=${PROC_UPTIME_COMPONENTS[0]}

COUNTER=0
while [ $COUNTER -lt $ITERATION_COUNT ]; do
  let COUNTER=COUNTER+1
  test_code
done

PROC_UPTIME_CONTENTS="$(</proc/uptime)"
PROC_UPTIME_COMPONENTS=($PROC_UPTIME_CONTENTS)
SYSTEM_UPTIME_END=${PROC_UPTIME_COMPONENTS[0]}

# Tool 'bc' does not print the leading zero, so that is why there is an "if" statement in the expression below.
ELAPSED_TIME="$(bc <<< "scale=2; result = $SYSTEM_UPTIME_END - $SYSTEM_UPTIME_BEGIN; if (result < 1 ) print 0; result")"

echo "Finished $ITERATION_COUNT iterations in $ELAPSED_TIME s."
