
WaitForSignals.sh
Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

Waits for Unix signals to arrive.

You can choose the action for each signal in the script's source code:
- Print the received signal's number and name, and then exit.
- Print the received signal's number and name, and then ignore it.
- Silently ignore the signal.
- Do not trap a signal at all (upon reception, the default response will then ensue).

This script is mainly useful during development or troubleshooting of Linux processes.
