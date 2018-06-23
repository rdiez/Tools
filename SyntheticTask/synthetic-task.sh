#!/bin/bash

# This script helps you create simple, dummy computing tasks that
# run in a given number of child processes for a given number of iterations.
#
# The goal is to simulate a parallel-build load that you would usually start
# with a "make -j nn" command. A number of parallel processes are started,
# which then run other processes sequentially. It is not exactly the same as
# a parallel make, but it is close enough for some performance test scenarios.
#
# When the tasks are completed, the elapsed wall-clock time is reported.
#
# You would normally use this tool to test your system's behaviour under load.
# For example, I have used it to determine how background, low-priority tasks
# affect the performance of foreground, high-priority tasks.
#
# There are certainly more-advanced load and benchmark tools. However, they often
# lack the necessary flexibility for a specific test and are hard to modify,
# so this little script might prove handy after all.
#
# Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


echo_dev_null_loop ()
{
  local -i INDEX
  for ((INDEX = 0; INDEX < NUMBER_OF_ITERATIONS_PER_SUBPROCESS; ++INDEX)); do
    echo "Do nothing useful here." > /dev/null
  done
}


empty_loop ()
{
  local -i INDEX
  for ((INDEX = 0; INDEX < NUMBER_OF_ITERATIONS_PER_SUBPROCESS; ++INDEX)); do
    :
  done
}


synthetic_task ()
{
  # You could use variables CHILD_INDEX and SUBPROCESS_INVOCATION_INDEX here
  # in order to select a particular task to run this time around.
  #   echo "Child process $CHILD_INDEX, suprocess $SUBPROCESS_INVOCATION_INDEX."

  $TASK_ROUTINE_NAME
}


child_process ()
{
  # echo "Child process $CHILD_INDEX starts for $NUMBER_OF_SUBPROCESS_INVOCATIONS_PER_CHILD subprocess invocations."

  # declare -g not supported in Bash 4.1.17, shipped with Cygwin.
  #   declare -gi SUBPROCESS_INVOCATION_INDEX

  if (( NUMBER_OF_SUBPROCESS_INVOCATIONS_PER_CHILD == 0 )); then
    SUBPROCESS_INVOCATION_INDEX=0
    synthetic_task
  else
    for ((SUBPROCESS_INVOCATION_INDEX = 0; SUBPROCESS_INVOCATION_INDEX < NUMBER_OF_SUBPROCESS_INVOCATIONS_PER_CHILD; ++SUBPROCESS_INVOCATION_INDEX)); do
      synthetic_task &
      wait "$!"
    done
  fi

  # echo "Child process ends."
}


read_uptime ()
{
  local PROC_UPTIME_CONTENTS
  PROC_UPTIME_CONTENTS="$(</proc/uptime)"

  local PROC_UPTIME_COMPONENTS
  IFS=$' \t' read -r -a PROC_UPTIME_COMPONENTS <<< "$PROC_UPTIME_CONTENTS"

  UPTIME=${PROC_UPTIME_COMPONENTS[0]}
}


# ------------ Entry point ------------

if [ $# -ne 4 ]; then
  echo
  echo "Invalid command-line arguments. See this script's source code for more information."
  echo
  exit 1
fi


#  ---------- Command-line arguments, begin ----------

# How many processes should start in parallel. This is similar to GNU Make's -j argument.
# A value of 0 child process means the current process will run the synthetic task,
# whereas a value of 1 creates a child process that then runs the task.
declare -i NUMBER_OF_CHILD_PROCESSES="$1"

# How may times each parallel child process should run the synthetic task in a subprocess.
# Subprocesses are NOT started in parallel, but run sequentially.
# A value of 0 here means that the child processes will run the synthetic task once
# by themselves, whereas a value of 1 would make them create a child subprocess in order to
# run the task once.
declare -i NUMBER_OF_SUBPROCESS_INVOCATIONS_PER_CHILD="$2"

declare -i NUMBER_OF_ITERATIONS_PER_SUBPROCESS="$3"

# Which task to run. For example, "empty_loop" or "echo_dev_null_loop".
TASK_ROUTINE_NAME="$4"

#  ---------- Command-line arguments, end ----------

read_uptime
SYSTEM_UPTIME_BEGIN="$UPTIME"

if (( NUMBER_OF_CHILD_PROCESSES == 0 )); then
  echo "Starting synthetic task..."
  CHILD_INDEX=0
  child_process
else

  echo "Starting $NUMBER_OF_CHILD_PROCESSES child process(es)..."

  declare -a SUBPROCESSES
  declare -i CHILD_INDEX

  for ((CHILD_INDEX = 0; CHILD_INDEX < NUMBER_OF_CHILD_PROCESSES; ++CHILD_INDEX)); do
    child_process &
    SUBPROCESSES+=($!)
  done

  echo "Waiting for all child processes to finish..."

  declare -i INDEX
  for ((INDEX = 0; INDEX < NUMBER_OF_CHILD_PROCESSES; ++INDEX)); do

    declare -i JOB_ID
    JOB_ID="${SUBPROCESSES[$INDEX]}"
    wait "$JOB_ID"

  done
fi

read_uptime
SYSTEM_UPTIME_END="$UPTIME"

# Tool 'bc' does not print the leading zero, so that is why there is an "if" statement in the expression below.
ELAPSED_TIME="$(bc <<< "scale=2; result = $SYSTEM_UPTIME_END - $SYSTEM_UPTIME_BEGIN; if (result < 1 ) print 0; result")"

echo "All child processes finished, elapsed time: $ELAPSED_TIME seconds"
