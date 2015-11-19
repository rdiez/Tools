
run-in-new-console.sh

  Runs the given shell command in a new console window.

  You would normally use this tool to launch interactive programs
  like GDB on a separate window.

  The script's help text is below.

open-serial-port-in-new-console.sh

  Uses run-in-new-console.sh to open a serial port on a new console window.
  The script knows many different tools (socat, minicom, gtkterm, ...),  so you can
  experiment until you find the right one for you.


---- run-in-new-console.sh help text ----

run-in-new-console.sh version 1.05
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to launch interactive programs
like GDB on a separate window. Another example would be to start a socat connection
to a serial port and leave it in the background (on another window) for later use.
In these scenarios you probably want to start run-in-new-console.sh as a background job
(in bash, append '&' to the whole run-in-new-console.sh command).

The shell command to run is passed as a single string and is executed with "bash -c".

After running the user command, depending on the specified options and the success/failure outcome,
this script will prompt the user inside the new console before closing it.
If the user commands runs a tool that changes stdin settings, like "socat STDIO,nonblock=1" does,
the prompting may fail with error message "read error: 0: Resource temporarily unavailable".
I have not found an easy work-around for this issue. Sometimes, you may
be able to pipe /dev/null to the stdin of those programs which manipulate stdin flags,
so that they do not touch stdin after all.

If you want to disable any prompting at the end, specify option --autoclose-on-error
and do not pass option --remain-open .

Syntax:
  run-in-new-console.sh <options...> [--] "shell command to run"

Options:
 --remain-open         The console should remain open after the command terminates.
                       Otherwise, the console closes automatically if the command was successful.

 --autoclose-on-error  By default, the console remains open if an error occurred
                       (on non-zero status code). This helps troubleshoot the command to run.
                       This option always closes the console after the command terminates,
                       regardless of the status code.

 --terminal-type=xxx  Use the given terminal emulator, defaults to 'konsole'
                      (the only implemented type at the moment).

 --konsole-title="my title"
 --konsole-icon="icon name"  Icons are normally .png files on your system.
                             Examples are kcmkwm or applications-office.
 --konsole-no-close          Keep the console open after the command terminates.
                             Option --remain-open is more comfortable, as you can type "exit"
                             to close the console. This option can also help debug
                             run-in-new-console.sh itself.
 --konsole-discard-stderr    Sometimes Konsole spits out too many errors or warnings on the terminal
                             where run-in-new-console.sh runs. For example, I have seen often D-Bus warnings.
                             This option keeps your terminal clean at the risk of missing
                             important error messages.

 --help     displays this help text
 --version  displays the tool's version number (currently 1.05)
 --license  prints license information

Usage example, as you would manually type it:
  ./run-in-new-console.sh "bash"

From a script you would normally use it like this:
  /path/run-in-new-console.sh -- "$CMD"

Exit status: 0 means success. Any other value means error.

If you wish to contribute code for other terminal emulators, please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de
