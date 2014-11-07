
background.sh version 2.3
Copyright (c) 2011-2014 R. Diez - Licensed under the GNU AGPLv3

This tool runs the given process with a low priority under a combination of ('time' + 'tee') commands and displays a visual notification when finished.

The visual notification consists of a transient desktop taskbar indication (if command 'notify-send' is installed) and a permanent modal message box. If you are sitting in front of the screen, the taskbar notification should catch your attention, even if the dialog box remains hidden beneath other windows. Should you miss the notification, the dialog box remains there until manually closed.

This tool is useful in the following scenario:
- You need to run a long process, such as copying a large number of files or recompiling a big software project.
- You want to carry on using the computer for other tasks. That long process should run with a low CPU and/or disk priority in the background. By default, the process' priority is reduced to 15 with 'nice', but you can switch to 'ionice' or 'chrt', see variable LOW_PRIORITY_METHOD in this script's source code for more information.
- You want to leave the process' console (or emacs frame) open, in case you want to check its progress in the meantime.
- You might inadvertently close the console window at the end, so you need a log file with all the console output for future reference (the 'tee' command).
- You may not notice when the process has completed, so you would like a visible notification in your windowing environment (like KDE).
- You would like to know immediately if the process succeeded or failed (an exit code of zero would mean success).
- You want to know how long the process took, in order to have an idea of how long it may take the next time around (the 'time' command).
- You want all that functionality conveniently packaged in a script that takes care of all the details.
- All that should work under Cygwin on Windows too.

Syntax:
  background.sh <options...> <--> command <command arguments...>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 2.3)
 --license  prints license information

Usage examples:
  ./background.sh -- echo "Long process runs here..."
  ./background.sh -- sh -c "exit 5"

Caveat: If you start several instances of this script, you should do it from different directories, as the log filename is hard-coded to "BackgroundCommand.log" and it will be overwritten each time.

Exit status: Same as the command executed. Note that this script assumes that 0 means success.

Still to do:
- This script could take optional parameters with the name of the log file, the 'nice' level and the visual notification method.
- Linux 'cgroups', if available, would provide a better CPU and/or disk prioritisation.
- Under Cygwin on Windows there is not taskbar notification yet, only the message box is displayed.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

