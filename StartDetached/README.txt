
StartDetached.sh version 1.02
Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3

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
in my .bashrc file:
  alias sd='StartDetached.sh'
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
 --version  displays the tool's version number (currently 1.02)
 --license  prints license information

Usage examples
  ./StartDetached.sh git gui

Caveat: Some shell magic may be lost in the way. Consider the following example:
   ./StartDetached.sh ls -la
Command 'ls' may be actually be an internal shell function or an alias to 'ls --color=auto',
but that will not be taken into consideration any more when using this script.
For example, the external /bin/echo tool will be executed instead of the shell's
built-in version.

Exit status: 0 on success, some other value on failure.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

