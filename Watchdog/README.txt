
watchdog.sh version 1.02
Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

This script runs a user command if the given file has not been modified in the last x seconds.

Note that the file is created, or its last modified time updated, on startup (with 'touch').

See companion script constantly-touch-file-over-ssh.sh for a possible counterpart.
In this case, you may want to start this script on the remote host with tmux.

Syntax:
  watchdog.sh <options> [--] <filename>  <timeout in seconds>  command <command arguments...>

Exit status: 0 means success, any other value means failure. If the user command runs, then its exit status is returned.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

