
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

run-in-new-console.sh version 1.10
Copyright (c) 2014-2017 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to launch interactive programs
like GDB on a separate window. Another example would be to start a socat connection
to a serial port and leave it in the background (on another window) for later use.
In these scenarios you probably want to start run-in-new-console.sh as a background job
(in bash, append '&' to the whole run-in-new-console.sh command).

The shell command to run is passed as a single string and is executed with "bash -c".

After running the user command, depending on the specified options and the success/failure outcome,
this script will prompt the user inside the new console window before closing it. The goal is to avoid
flashing an error message for a very short time and then closing the window immediately afterwards.
If the command fails, the user should have the chance to inspect the corresponding
error message at leisure.

The prompt asks the user to type "exit" and press Enter, which should be "stored in muscle memory"
for most users. Prompting for just Enter is not enough in my opinion, as the user will often press Enter
during a long-running command, either inadvertently or maybe to just visually separate text lines
in the command's output. Such Enter keypresses are usually forever remembered in the console,
so that they would make the console window immediately close when the command finishes much later on.

If you want to disable any prompting at the end, specify option --autoclose-on-error
and do not pass option --remain-open-on-success .

In the rare cases where the user runs a command that changes stdin settings, like "socat STDIO,nonblock=1"
does, the prompting may fail with error message "read error: 0: Resource temporarily unavailable".
I have not found an easy work-around for this issue. Sometimes, you may
be able to pipe /dev/null to the stdin of those programs which manipulate stdin flags,
so that they do not touch the real stdin after all.

Syntax:
  run-in-new-console.sh <options...> [--] "shell command to run"

Options:
 --remain-open-on-success  The console should remain open after the command successfully
                           terminates (on a zero status code). Otherwise, the console closes
                           automatically if the command was successful.

 --autoclose-on-error  By default, the console remains open if an error occurred
                       (on non-zero status code). This helps troubleshoot the command to run.
                       This option closes the console after the command terminates with an error.

 --terminal-type=xxx  Use the given terminal emulator. Options are:
                      - 'auto' (the default) uses the first one found on the system from the available
                        terminal types below, in some arbitrary order hard-coded in this script,
                        subject to change without notice in any future versions.
                      - 'konsole' for Konsole, the usual KDE terminal.
                      - 'xfce4-terminal' for xfce4-terminal, the usual Xfce terminal.

 --console-title="my title"

 --console-no-close          Always keep the console open after the command terminates,
                             but using some console-specific option.
                             Note that --remain-open-on-success is usually better option,
                             because the user can then close the console by typing with
                             the keyboard. Otherwise, you may be forced to resort to
                             the mouse in order to close the console window.
                             This option can also help debug run-in-new-console.sh itself.

 --console-icon="icon name"  Icons are normally .png files on your system.
                             Examples are "kcmkwm" or "applications-office".
                             You can also specify the path to an image file (like a .png file).

 --console-discard-stderr    Sometimes Konsole spits out too many errors or warnings on the terminal
                             where run-in-new-console.sh runs. For example, I have seen often D-Bus
                             warnings. This option keeps your terminal clean at the risk of missing
                             important error messages.

 --help     displays this help text
 --version  displays the tool's version number (currently 1.10)
 --license  prints license information

Usage example, as you would manually type it:
  ./run-in-new-console.sh "bash"

From a script you would normally use it like this:
  /path/run-in-new-console.sh -- "$CMD"

Exit status: 0 means success. Any other value means error.

If you wish to contribute code for other terminal emulators, please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de
