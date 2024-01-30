#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r VERSION_NUMBER="1.09"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2017-2024 R. Diez - Licensed under the GNU AGPLv3"
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
  echo "in my .bashrc file for convenience:"
  echo "  alias sd='/some/dir/$SCRIPT_NAME'"
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
  echo " --log-tag-name=<str>  Log entries are tagged with the current username"
  echo "                       concatenated with the name of this script and its PID."
  echo "                       This option changes the script name component."
  echo
  echo "Usage example:"
  echo "  ./$SCRIPT_NAME git gui"
  echo
  echo "Caveat: Some shell magic may be lost in the way. Consider the following example:"
  echo "   ./$SCRIPT_NAME ls -la"
  echo "Command 'ls' may be actually be an internal shell function or an alias to 'ls --color=auto',"
  echo "but that will not be taken into consideration any more when using this script."
  echo "For example, the external /bin/echo tool will be executed instead of the shell's"
  echo "built-in version. If you need your shell magic, you need to run your command with bash -c 'cmd'"
  echo "or a similar way."
  echo
  echo "Exit status: 0 on success, some other value on failure."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2017-2024 R. Diez

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


process_command_line_argument ()
{
  case "$OPTION_NAME" in
    help)
        display_help
        exit $EXIT_CODE_SUCCESS
        ;;
    version)
        echo "$VERSION_NUMBER"
        exit $EXIT_CODE_SUCCESS
        ;;
    license)
        display_license
        exit $EXIT_CODE_SUCCESS
        ;;
    log-tag-name)
        if [[ $OPTARG = "" ]]; then
          abort "The --log-tag-name option has an empty value.";
        fi
        LOG_TAG_NAME="$OPTARG"
        ;;
    *)  # We should actually never land here, because parse_command_line_arguments() already checks if an option is known.
        abort "Unknown command-line option \"--${OPTION_NAME}\".";;
  esac
}


parse_command_line_arguments ()
{
  # The way command-line arguments are parsed below was originally described on the following page:
  #   http://mywiki.wooledge.org/ComplexOptionParsing
  # But over the years I have rewritten or amended most of the code myself.

  if false; then
    echo "USER_SHORT_OPTIONS_SPEC: $USER_SHORT_OPTIONS_SPEC"
    echo "Contents of USER_LONG_OPTIONS_SPEC:"
    for key in "${!USER_LONG_OPTIONS_SPEC[@]}"; do
      printf -- "- %s=%s\\n" "$key" "${USER_LONG_OPTIONS_SPEC[$key]}"
    done
  fi

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  local MY_OPT_SPEC=":-:$USER_SHORT_OPTIONS_SPEC"

  local OPTION_NAME
  local OPT_ARG_COUNT
  local OPTARG  # This is a standard variable in Bash. Make it local just in case.
  local OPTARG_AS_ARRAY

  while getopts "$MY_OPT_SPEC" OPTION_NAME; do

    case "$OPTION_NAME" in

      -) # This case triggers for options beginning with a double hyphen ('--').
         # If the user specified "--longOpt"   , OPTARG is then "longOpt".
         # If the user specified "--longOpt=xx", OPTARG is then "longOpt=xx".

         if [[ "$OPTARG" =~ .*=.* ]]  # With this --key=value format, only one argument is possible.
         then

           OPTION_NAME=${OPTARG/=*/}
           OPTARG=${OPTARG#*=}
           OPTARG_AS_ARRAY=("")

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT != 1 )); then
             abort "Command-line option \"--$OPTION_NAME\" does not take 1 argument."
           fi

           process_command_line_argument

         else  # With this format, multiple arguments are possible, like in "--key value1 value2".

           OPTION_NAME="$OPTARG"

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT == 0 )); then
             OPTARG=""
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           elif (( OPT_ARG_COUNT == 1 )); then
             # If this is the last option, and its argument is missing, then OPTIND is out of bounds.
             if (( OPTIND > $# )); then
               abort "Option '--$OPTION_NAME' expects one argument, but it is missing."
             fi
             OPTARG="${!OPTIND}"
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           else
             OPTARG=""
             # OPTARG_AS_ARRAY is not standard in Bash. I have introduced it to make it clear that
             # arguments are passed as an array in this case. It also prevents many Shellcheck warnings.
             OPTARG_AS_ARRAY=("${@:OPTIND:OPT_ARG_COUNT}")

             if [ ${#OPTARG_AS_ARRAY[@]} -ne "$OPT_ARG_COUNT" ]; then
               abort "Command-line option \"--$OPTION_NAME\" needs $OPT_ARG_COUNT arguments."
             fi

             process_command_line_argument
           fi

           ((OPTIND+=OPT_ARG_COUNT))
         fi
         ;;

      *) # This processes only single-letter options.
         # getopts knows all valid single-letter command-line options, see USER_SHORT_OPTIONS_SPEC above.
         # If it encounters an unknown one, it returns an option name of '?'.
         if [[ "$OPTION_NAME" = "?" ]]; then
           abort "Unknown command-line option \"$OPTARG\"."
         else
           # Process a valid single-letter option.
           OPTARG_AS_ARRAY=("")
           process_command_line_argument
         fi
         ;;
    esac
  done

  shift $((OPTIND-1))
  ARGS=("$@")
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

  local LOG_ID_WITHOUT_PID="$USER-${LOG_TAG_NAME}"
  local LOG_ID="${LOG_ID_WITHOUT_PID}[$BASH_PID]"


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


  if [[ $OSTYPE = "cygwin" ]]; then

    echo "Under Cygwin, log output ends up by default in the Windows Application Log."
    echo "Look for log entries from source \"$LOG_ID\"."

  else

    echo "Use a tool like ksystemlog or mate-system-log to view the application's stdout and stderr output."
    echo "Filter from \"$CURRENT_DATE\" and by \"$LOG_ID\" for convenience. "

    # If the system is using Systemd, offer an alternative.
    # Tool 'journalctl' apparently strips the PID from the end of the tag
    # if enclosed in brackets, so use LOG_ID_WITHOUT_PID instead of LOG_ID.
    local JOURNALCTL_CMD="journalctl"
    if type -P "$JOURNALCTL_CMD" >/dev/null; then
      echo "Alternatively, use a command like this:"
      local MSG
      printf -v MSG \
             "%q  --identifier=%q  --since=%q" \
             "$JOURNALCTL_CMD" \
             "$LOG_ID_WITHOUT_PID" \
             "$CURRENT_DATE"
      echo "$MSG"
    fi

  fi


  local QUOTED_COMMAND
  # This yields an extra space at the end.
  printf -v QUOTED_COMMAND -- "%q " "$@"
  # Remove that trailing space.
  QUOTED_COMMAND="${QUOTED_COMMAND% }"

  # If we are running inside a terminal, and the terminal closes, we may receive SIGHUP,
  # which will probably make us terminate. But we want the started process to keep running
  # in the background, even if the terminal is no longer available.
  #
  # This script itself does not need to ignore SIGHUP, but if we do it at this level,
  # any child processes will inherit the ignoring of SIGHUP.
  #
  # We need to ignore SIGHUP before starting both the main background process
  # and the logger process.
  #
  #
  # Blocking SIGHUP by default is not enough, because some processes handle SIGHUP themselves.
  # I believe Emacs is one such example, and I haven't found a way yet to tell it
  # to ignore SIGHUP.
  #
  # That is why we are using 'setsid' below. The controlling terminal, and the terminal emulator,
  # tend to send SIGHUP to the process leader. With 'setsid', we are running the child process
  # in a separate process group, so that is should not get SIGHUP when the terminal closes.
  #
  # We could probably optimise this script to call 'setsid' only once for the whole pipeline.
  #
  # An alternatively to 'setsid' would be to activate job control (monitor mode)
  # before launching the child process. You can do that in a subshell to avoid
  # modifying the current shell settings:
  #   (set -m; exec process_in_its_own_group)
  #
  # In fact, by using 'setsid', we do not really need to ignore SIGHUP anymore.

  trap -- '' SIGHUP

  # If 'exec' fails, you can set "shopt execfail" in order to prevent the shell from exiting.
  # But, if you want to print an error message, you have to restore stdout and/or stderr too,
  # because a failed 'exec' does not restore them. I consider this to be a shortcoming in Bash.
  #
  # Beware that 'execfail' does not work in a subshell environment.
  # I reported this issue in Bash' mailing list, but the maintainer is unwilling to fix it.
  #
  # Properly reporting any other error in a background command like this (commands ending with '&')
  # is difficult. With luck, the user will find related error messages in the syslog.

  # We could check here with "if [ -t 0 ]" whether stdin is a terminal. If not,
  # we do not need to redirect stdin to /dev/null below, so that the user can feed data
  # this way to the background process.

  {
    # We want to log the command that will run on the next line.
    echo "Running command: $QUOTED_COMMAND"

    # shellcheck disable=SC2093
    exec -- setsid -- "$@"

    # If 'exec' succeeds, this part of the script stops here. Otherwise, a non-interactive shell
    # should automatically exit anyway.
    abort "Internal error in method exec1."  ;  # Semicolon at the end needed by the {} grouping.

    # Without the 'exec' below, a top-level Bash process remains waiting for the logger process to exit.
    # That Bash process does not close its stdout, so if you are redirecting the output
    # of this script to a 'tee' process, 'tee' will not exit until the background process exits,
    # and that is not what we want.

  } </dev/null > >( exec setsid -- "$LOGGER_CMD" --tag "$LOG_ID" >/dev/null 2>&1 ) 2>&1  &

  # This call to 'disown' is not really necessary, as non-interactive Bash instances do not
  # forward SIGHUP to the child processes.
  # You would need to use 'disown' if you activate job control with "set -m",
  # see above for an alternative to using 'setsid' that would do that.
  disown -h %%
}


# ------ Entry Point (only by convention) ------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [log-tag-name]=1 )

LOG_TAG_NAME="$SCRIPT_NAME"

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} < 1 )); then
  abort "No command specified. Run this tool with the --help option for usage information."
fi


# Other methods could be:
# - Output to rotated log files.
# - Output to some intelligent log file rotator tool or daemon, which could then limit
#   the total file size, compress them, etc.
# - Drop all output.
declare -r METHOD="exec1"

case "$METHOD" in

  exec1) method_exec1 "${ARGS[@]}";;

  *) abort "Unknown method \"$METHOD\".";;

esac

if false; then
  echo "$SCRIPT_NAME finished."
fi
