
WaitForSignals.sh version 1.03

This script waits for Unix signals to arrive.

You can choose the action for each signal in the script source code:
- Print the received signal's number and name, and then exit.
- Print the received signal's number and name, and then exit after a delay.
  This is useful for testing whether a process pipeline is quitting abruptly
  upon reception of a signal, or is waiting for all process to terminate gracefully.
- Print the received signal's number and name, and then let that same signal kill
  this script, with or without a delay.
  This is in fact the recommended way of terminating upon reception of a signal,
  after doing any clean-up work.
  This script assumes that the default signal disposition on start-up is set to "terminate process",
  because Bash cannot only reset the signal dispositions to their original value upon entry.
- Print the received signal's number and name, and then ignore it.
- Silently ignore the signal.
- Do not trap a signal at all (upon reception, the default response will then ensue).

This script is mainly useful during development or troubleshooting of Linux processes.

Copyright (c) 2017-2020 R. Diez - Licensed under the GNU AGPLv3
