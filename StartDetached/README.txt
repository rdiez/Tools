
StartDetached.sh version 1.09
Copyright (c) 2017-2024 R. Diez - Licensed under the GNU AGPLv3

Starting a graphical application like "git gui" from a shell console is problematic.
If you just type "git gui", your console hangs waiting for the application to exit.
If you type "git gui &" to start it as a background process, the application may
asynchrously litter your terminal with GTK warnings and the like.
Say you then close your terminal with the 'exit' command. Your graphical application will
remain running. However, closing the terminal window with the mouse will send a SIGHUP
to the shell, which will probably forward it to all background processes,
automatically killing your "git gui" with it.
The closing issue can be avoided with 'nohup' or 'disown', but each has its little
annoyances. If you do not want to lose the application output, just in case some
useful troubleshooting information pops up, you need to manage (limit the size, rotate)
your application log files.

This script is my attempt at fixing these issues. I have placed the following alias
in my .bashrc file for convenience:
  alias sd='/some/dir/StartDetached.sh'
I then start graphical applications like this:
  sd git gui
The application is started detached from the console, and its output (stdout and stderr)
are redirected to syslog. This assumes that there will be little output, which is
normally the case with graphical applications. Otherwise, you will fill your syslog
with loads of rubbish.

Syntax:
  StartDetached.sh <options...> <--> command <command arguments...>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.09)
 --license  prints license information
 --log-tag-name=<str>  Log entries are tagged with the current username
                       concatenated with the name of this script and its PID.
                       This option changes the script name component.

Usage example:
  ./StartDetached.sh git gui

Caveat: Some shell magic may be lost in the way. Consider the following example:
   ./StartDetached.sh ls -la
Command 'ls' may be actually be an internal shell function or an alias to 'ls --color=auto',
but that will not be taken into consideration any more when using this script.
For example, the external /bin/echo tool will be executed instead of the shell's
built-in version. If you need your shell magic, you need to run your command with bash -c 'cmd'
or a similar way.

Exit status: 0 on success, some other value on failure.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

