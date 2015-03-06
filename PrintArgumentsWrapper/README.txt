
print-arguments-wrapper.sh version 2.0
Copyright (c) 2011-2014 R. Diez - Licensed under the GNU AGPLv3

When writing complex shell scripts, sometimes you wonder if a particular process is getting the right arguments and the right environment variables. Just prefix a command with the name of this script, and it will dump all arguments and environment variables to the console before starting the child process.

Syntax:
  print-arguments-wrapper.sh <options...> command <command arguments...>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently 2.0)
 --license  prints license information

Usage examples
  ./print-arguments-wrapper.sh echo "test"

Caveat: Some shell magic may be lost in the way. Consider the following example:
   ./print-arguments-wrapper.sh ls -la
Command 'ls' may be actually be an internal shell function or an alias to 'ls --color=auto', but that will not be taken into consideration any more when using this wrapper script. For example, the external /bin/echo tool will be executed instead of the shell built-in version.

Exit status: Same as the command executed.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de


Additional tool program-argument-printer.pl is aimed at Perl users. It is no wrapper (it does not run the command), it just prints the arguments it received and quits.
