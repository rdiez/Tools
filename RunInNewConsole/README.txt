
run-in-new-console.sh version 1.00
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to start interactive programs
like gdb. Another example would be to start a socat connection to
a serial port and leave it in the background for later use.

The command is passed as a single string and is executed with "bash -c".

See script "open-serial-port-in-new-console.sh" for a usage example.

Syntax:
  run-in-new-console.sh <options...> [--] "shell command to run"

Options:
 --terminal-type=xxx  Use the given terminal emulator, defaults to 'konsole'
                      (the only implemented type at the moment).
 --konsole-title="my title"
 --konsole-icon="icon name"  Icons are normally .png files on your system.
                             Examples are kcmkwm or applications-office.
 --konsole-no-close          Keep the console open after the command terminates.
                             Useful mainly to see why the command is failing.
 --konsole-discard-stderr    Sometimes Konsole spits out too many errors or warnings.
 --help     displays this help text
 --version  displays the tool's version number (currently 1.00)
 --license  prints license information

Usage example, as you would manually type it:
  ./run-in-new-console.sh "bash"

From a script you would normally use it like this:
  /path/run-in-new-console.sh -- "$CMD"

Exit status: 0 means success. Any other value means error.

If you wish to contribute code for other terminal emulators, please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

