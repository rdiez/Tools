
background.sh version 2.64
Copyright (c) 2011-2020 R. Diez - Licensed under the GNU AGPLv3

This tool runs the given Bash command with a low priority, copies its output to a log file, and displays a visual notification when finished.

The visual notification consists of a transient desktop taskbar indication (if command 'notify-send' is installed, not implemented on Microsoft Windows/Cygwin) and a permanent message box (a window that pops up). If you are sitting in front of the screen, the taskbar notification should catch your attention, even if the message box remains hidden beneath other windows. Should you miss the notification, the message box remains open until manually closed. If your desktop environment makes it hard to miss notifications, you can disable the message box, see ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION in this script's source code, or see environment variable BACKGROUND_SH_ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION below.

This tool is useful in the following scenario:
- You need to run a long process, such as copying a large number of files or recompiling a big software project.
- You want to carry on using the computer for other tasks. That long process should run with a low CPU and/or disk priority in the background. By default, the process' priority is reduced to 15 with 'nice', but you can switch to 'ionice', 'chrt' or 'systemd-run' with environment variable BACKGROUND_SH_LOW_PRIORITY_METHOD, see LOW_PRIORITY_METHOD in this script's source code for more information.
- You want to leave the command's console (or Emacs frame) open, in case you want to check its progress in the meantime.
- You might inadvertently close the console window at the end, so you need a persistent log file with all the console output for future reference. You can choose where the log files land and whether they rotate, see option --log-file and variable LOG_FILES_DIR in this script's source code.
- The log file should optionally optimise away the carriage return trick often used to update a progress indicator in place on the current console line.
- You may not notice when the process has completed, so you would like a visible notification in your desktop environment (like KDE or Xfce). Or an e-mail. Or both.
- You would like to know immediately if the process succeeded or failed (an exit code of zero would mean success).
- You want to know how long the process took, in order to have an idea of how long it may take the next time around.
- You want the PID of your command's parent process automatically displayed at the beginning, in order to temporarily suspend all related child processes at once with pkill, should you need the full I/O performance at this moment for something else.
- You want all that functionality conveniently packaged in a script that takes care of all the details.
- All that should work under Cygwin on Windows too.

Syntax:
  background.sh <options...> <--> command <command arguments...>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 2.64)
 --license  prints license information
 --notify-only-on-error  Some scripts display their own notifications,
                         so only notify if something went wrong.
 --no-desktop            Do not issue any desktop notifications at the end.
 --email                 Sends a notification e-mail when the command has finished.
                         See below for e-mail configuration information.
 --friendly-name=name    A name that appears in the log and in the notifications,
                         to remind you what the long-running command was about.
 --no-console-output     Places all command output only in the log file. Depending on
                         where the console is, you can save CPU and/or network bandwidth.
 --log-file=filename     Instead of rotating log files, use a fixed filename.
                         Specify /dev/null for no log file.
 --filter-log            Filters the command's output with FilterTerminalOutputForLogFile.pl
                         before placing it in the log file.
 --compress-log          Compresses the log file. Log files tend to be very repetitive
                         and compress very well. Note that Cygwin has issues with FIFOs
                         as of feb 2019, so this option will probably hang on Cygwin.
 --memory-limit=x        Passed as --property=MemoryLimit=x to systemd-run.
                         Use suffix K, M, G or T for units KiB, MiB, GiB and TiB.
                         You can set a default with environment variable BACKGROUND_SH_MEMORY_LIMIT.
                         Special value 'infinity' cancels the default limit.
                         Only available when using low-priority method 'systemd-run'.
                         See further below for more information.
 --no-prio               Do not change the child process priority.

Environment variables:
  BACKGROUND_SH_ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION=true/false
  BACKGROUND_SH_LOW_PRIORITY_METHOD=none/nice/ionice/ionice+chrt/systemd-run
  BACKGROUND_SH_MEMORY_LIMIT=1024MiB

Usage examples:
  ./background.sh -- echo "Long process runs here..."
  ./background.sh -- sh -c "exit 5"

Usage scenario for remote servers:

Say that you are running a long process on a server over an SSH network connection. If the connection is lost, the process terminates, unless you are using something like 'screen' or 'tmux', but then you will probably not have a desktop session for the visual notification. An email notification is probably better. In such a remote session, you do not expect any interaction with the long process, so trying to read from stdin should fail. You will probably want a fixed log filename too. In this scenario, the following options are probably more suitable:

  ./background.sh --log-file=output.log  --no-desktop  --email -- your_command  </dev/null

Notification e-mails are sent with S-nail. You will need a .mailrc configuration file
in your home directory. There is a .mailrc example file next to this script.

Caveats:
- If you start several instances of this script and you are using a fixed log filename (without log file rotation), you should do it from different directories. This script attempts to detect such a situation by creating a temporary lock file named after the log file and obtaining an advisory lock on it with flock (which depending on the underlying filesystem may have no effect).
- There is no signal handling. Usual signals like SIGINT (pressing Ctrl+C) and SIGHUP (closing the terminal window) will stop the script abruptly, and the log file will be incomplete.
- There is no log file size limit, so this script is not suitable for processes that continuously write to stdout or stderr without bounds.

About the --memory-limit option:
  The Linux filesystem cache is braindead (as of Kernel 5.0.0 in september 2019). Say you have 2 GiB of RAM and 
  you copy 2 GiB's worth of data from one disk directory to another. That will effectively flush the Linux
  filesystem cache, and you don't even have to be root. Anything you want to do afterwards will have to reload
  any other files needed from disk, which means that the system will always respond slowly after copying large files.

  In order to reduce the cache impact on other processes, I have looked for ways to limit cache usage.
  The only way I found is to set a memory limit in a cgroup, but unfortunately that affects all memory usage
  within the cgroup, and not just the file cache. The only tool I found to painlessly create a temporary
  cgroup is 'systemd-run', and even this way is not without rough edges.

  If your command hits the memory limit, the OOM killer will probably terminate the whole group, and the error message
  will simply be 'Killed'. Unfortunately, the only alternative OOM behaviour is to pause processes until
  more memory is available, which does not really work well in practice.
  Beware that sometimes setting the memory limit too low will not kill your process, but it will make it cause
  'virtual memory thrashing', severely degrading overall system performance. I have seen this effect with
  Ubuntu 18.04.4 and par2's argument -m .

Exit status: Same as the command executed. Note that this script assumes that 0 means success.

Still to do:
- This script could take more optional parameters like the 'nice' level.
- The Linux 'cgroups' feature would provide a better CPU and/or disk prioritisation. The 'systemd-run' method does use cgroups, but it depends on systemd and this script does not offer much flexibility at the moment.
- Under Cygwin on Windows there is not taskbar notification yet, only the message box is displayed. I could not find an easy way to create a taskbar notification with a .vbs or similar script.
- Log file rotation could take the log file sizes into consideration.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

