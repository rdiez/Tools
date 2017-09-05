#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="StartDetached.sh"
declare -r VERSION_NUMBER="1.00"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "Starting a graphical application like \"git gui\" from a shell console is problematic."
  echo "If you just type \"git gui\", your console hangs waiting for the application to exit."
  echo "If you type \"git gui &\" to start it as a background process, the application may"
  echo "asynchrously litter your terminal with GTK warnings and the like."
  echo "Say you then close your terminal with the 'exit' command. Your graphical application will"
  echo "remain running. However, closing the terminal window with the mouse will send a SIGHUP"
  echo "to the shell, which will probably forward it to all background processes,"
  echo "automatically killing your \"git gui\" with it."
  echo "The closing issue can be avoided with 'nohup' or 'disown', but each has its little"
  echo "annoyances. If you do not want to lose the application output, just in case some"
  echo "useful troubleshooting information pops up, you need to manage (limit the size, rotate)"
  echo "your application log files."
  echo
  echo "This script is my attempt at fixing these issues. I have placed the following alias"
  echo "in my .bashrc file:"
  echo "  alias sd='StartDetached.sh'"
  echo "I then start graphical applications like this:"
  echo "  sd git gui"
  echo "The application is started detached from the console, and its output (stdout and stderr)"
  echo "are redirected to syslog. This assumes that there will be little output, which is"
  echo "normally the case with graphical applications. Otherwise, you will fill your syslog"
  echo "with loads of rubbish."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> command <command arguments...>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Usage examples"
  echo "  ./$SCRIPT_NAME git gui"
  echo
  echo "Caveat: Some shell magic may be lost in the way. Consider the following example:"
  echo "   ./$SCRIPT_NAME ls -la"
  echo "Command 'ls' may be actually be an internal shell function or an alias to 'ls --color=auto',"
  echo "but that will not be taken into consideration any more when using this script."
  echo "For example, the external /bin/echo tool will be executed instead of the shell's"
  echo "built-in version."
  echo
  echo "Exit status: 0 on success, some other value on failure."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2017 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


# The main drawback of this method is that each process started will carry an extra 'logger' process with it.

method_exec1()
{
  local COMMAND="$1"

  # Try to catch the most typical error: the command does not exist as a file.
  # Bash' built-in commands, aliases, etc. will not work with 'exec'.
  type -P "$COMMAND" >/dev/null || abort "Command '$COMMAND' not found."

  local BASH_PID="$$"

  local CURRENT_DATE
  printf -v CURRENT_DATE "%(%F %H:%M:%S)T"

  local LOG_ID="$SCRIPT_NAME-$BASH_PID"


  # In Debian, the 'logger' tools is installed by package 'bsdutils', which is marked as 'essential'.
  # Therefore, I guess we can assume that 'logger' is always installed.
  # However, if 'logger' is not present, the command below seems to succeed. Therefore,
  # just in case, I am checking that 'logger' is present.
  #
  # By the way, we could log stdout and stderr with separate priorities like this:
  #  > >(logger --priority user.info)  2> >(logger --priority user.warn)
  # But that would mean 2 extra processes per application.
  #
  # If Systemd is being used, an alternative would be echo blah | systemd-cat -t "some-tag".
  # In fact, according to systemd-cat's documentation, it would be more efficient
  # to execute "systemd-cat my_command" than to use a pipe.

  local LOGGER_CMD="logger"

  if ! type -P "$LOGGER_CMD" >/dev/null; then
    abort "Command \"$LOGGER_CMD\" not found."
  fi


  echo "Use a tool like ksystemlog to view the application's stdout and stderr output."
  echo "Filter from \"$CURRENT_DATE\" and by \"$LOG_ID\" for convenience. "

  # If the system is using Systemd, offer an alternative.
  local JOURNALCTL_CMD="journalctl"
  if type -P "$JOURNALCTL_CMD" >/dev/null; then
    echo "Alternatively, use a command like this:"
    echo sudo $JOURNALCTL_CMD  --identifier="$LOG_ID"  --since=\""$CURRENT_DATE"\"
  fi

  local QUOTED_COMMAND
  # This yields an extra space at the end.
  printf -v QUOTED_COMMAND -- "%q " "$@"
  # Remove that trailing space.
  QUOTED_COMMAND="${QUOTED_COMMAND% }"

  # If 'exec' fails, you can set "shopt execfail" in order to prevent the shell from exiting.
  # But, if you want to print an error message, you have to restore stdout and/or stderr too,
  # because a failed 'exec' does not restore them. I consider this to be a shortcoming in Bash.
  #
  # Beware that 'execfail' does not work in a subshell environment.
  # I reported this issue in Bash' mailing list, but the maintainer is unwilling to fix it.
  #
  # Properly reporting any other error in a background command like this (commands ending with '&')
  # is difficult. With luck, the user will find related error messages in the syslog.

  {
    # We want to log the command that we will be starting on the next line.
    echo "Running command: $QUOTED_COMMAND"

    exec -- "$@"

    # If 'exec' succeeds, this script stops here. Otherwise, a non-interactive shell
    # should automatically exit anyway.
    abort "Internal error in method exec1."  ;  # Semicolon at the end needed by the {} grouping.

  } </dev/null > >( "$LOGGER_CMD" --tag "$LOG_ID" >/dev/null 2>&1 ) 2>&1  &

  # This call to 'disown' is not really necessary, as non-interactive Bash instances do not
  # forward SIGHUP to the child processes.
  disown -h %%
}


# ----------- Entry point -----------

if [ $# -lt 1 ]; then
  echo
  echo "You need to specify at least one argument. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
fi

case "$1" in

  --help)
    display_help
    exit $EXIT_CODE_SUCCESS;;

  --license)
    display_license
    exit $EXIT_CODE_SUCCESS;;

  --version)
    echo "$VERSION_NUMBER"
    exit $EXIT_CODE_SUCCESS;;

  --) shift;;

  --*) abort "Unknown option \"$1\".";;

esac

if [ $# -eq 0 ]; then
  echo
  echo "No command specified. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
fi


# Other methods could be:
# - Output to rotated log files.
# - Output to some intelligent log file rotator tool or daemon, which could then limit
#   the total file size, compress them, etc.
METHOD="exec1"

case "$METHOD" in

  exec1) method_exec1 "$@";;

  *) abort "Unknown method \"$METHOD\".";;

esac
