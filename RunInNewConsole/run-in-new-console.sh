#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


VERSION_NUMBER="1.07"
SCRIPT_NAME="run-in-new-console.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014-2017 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script runs the given shell command in a new console window.

You would normally use this tool to launch interactive programs
like GDB on a separate window. Another example would be to start a socat connection
to a serial port and leave it in the background (on another window) for later use.
In these scenarios you probably want to start $SCRIPT_NAME as a background job
(in bash, append '&' to the whole $SCRIPT_NAME command).

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
  $SCRIPT_NAME <options...> [--] "shell command to run"

Options:
 --remain-open         The console should remain open after the command terminates.
                       Otherwise, the console closes automatically if the command was successful.

 --autoclose-on-error  By default, the console remains open if an error occurred
                       (on non-zero status code). This helps troubleshoot the command to run.
                       This option always closes the console after the command terminates,
                       regardless of the status code.

 --terminal-type=xxx  Use the given terminal emulator, defaults to 'konsole'.
                      'xfce4-terminal' is also available.

 --console-title="my title"

 --console-no-close          Keep the console open after the command terminates.
                             Option --remain-open is more comfortable, as you can type "exit"
                             to close the console. This option can also help debug
                             $SCRIPT_NAME itself.

 --console-icon="icon name"  Icons are normally .png files on your system.
                             Examples are "kcmkwm" or "applications-office".
                             You can also specify the path to an image file (like a .png file).

 --console-discard-stderr    Sometimes Konsole spits out too many errors or warnings on the terminal
                             where $SCRIPT_NAME runs. For example, I have seen often D-Bus warnings.
                             This option keeps your terminal clean at the risk of missing
                             important error messages.

 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example, as you would manually type it:
  ./$SCRIPT_NAME "bash"

From a script you would normally use it like this:
  /path/$SCRIPT_NAME -- "\$CMD"

Exit status: 0 means success. Any other value means error.

If you wish to contribute code for other terminal emulators, please drop me a line.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license ()
{
cat - <<EOF

Copyright (c) 2014-2017 R. Diez

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


process_long_option ()
{
  case "${opt}" in
    help)
        display_help
        exit 0
        ;;
    version)
        echo "$VERSION_NUMBER"
        exit 0
        ;;
    license)
        display_license
        exit 0
        ;;
    terminal-type)
        if [[ ${OPTARG:-} = "" ]]; then
          abort "The --terminal-type option has an empty value.";
        fi
        TERMINAL_TYPE="$OPTARG"
        ;;
    console-title)
        if [[ ${OPTARG:-} = "" ]]; then
          abort "The --console-title option has an empty value.";
        fi
        CONSOLE_TITLE="$OPTARG"
        ;;
    console-icon)
        if [[ ${OPTARG:-} = "" ]]; then
          abort "The --console-icon option has an empty value.";
        fi
        CONSOLE_ICON="$OPTARG"
        ;;
    console-no-close)
        CONSOLE_NO_CLOSE=1
        ;;
    remain-open)
        REMAIN_OPEN=1
        ;;
    autoclose-on-error)
        AUTOCLOSE_ON_ERROR=1
        ;;
    console-discard-stderr)
        CONSOLE_DISCARD_STDERR=1
        ;;
    *)  # We should actually never land here, because get_long_opt_arg_count() already checks if an option is known.
        abort "Unknown command-line option \"--${opt}\".";;
  esac
}


process_short_option ()
{
  case "${opt}" in
    *) abort "Unknown command-line option \"-$OPTARG\".";;
  esac
}


get_long_opt_arg_count ()
{
  if ! test "${USER_LONG_OPT_SPEC[$1]+string_returned_if_exists}"; then
    abort "Unknown command-line option \"--$1\"."
  fi

  OPT_ARG_COUNT=USER_LONG_OPT_SPEC[$1]
}


parse_command_line_arguments ()
{
  # The way command-line arguments are parsed below was originally described on the following page,
  # although I had to make a few of amendments myself:
  #   http://mywiki.wooledge.org/ComplexOptionParsing

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  # The rest are user-defined short options.
  MY_OPT_SPEC=":-:$USER_SHORT_OPTIONS_SPEC"

  while getopts "$MY_OPT_SPEC" opt; do
    case "${opt}" in
      -)  # This case triggers for options beginning with a double hyphen ('--').
          # If the user specified "--longOpt"   , OPTARG is then "longOpt".
          # If the user specified "--longOpt=xx", OPTARG is then "longOpt=xx".
          if [[ "${OPTARG}" =~ .*=.* ]]  # With this "--key=value" format, only one argument is possible. See alternative below.
          then
            opt=${OPTARG/=*/}
            get_long_opt_arg_count "$opt"
            if (( OPT_ARG_COUNT != 1 )); then
              abort "Option \"--$opt\" expects $OPT_ARG_COUNT argument(s)."
            fi
            OPTARG=${OPTARG#*=}
          else  # With this "--key value1 value2" format, multiple arguments are possible.
            opt="$OPTARG"
            get_long_opt_arg_count "$opt"
            OPTARG=(${@:OPTIND:$OPT_ARG_COUNT})
            ((OPTIND+=$OPT_ARG_COUNT))
          fi
          process_long_option
          ;;
      *) process_short_option;;
    esac
  done

  shift $((OPTIND-1))
  ARGS=("$@")
}


# ------- Entry point -------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments a long option expects.
# All known options must be listed, even those with 0 arguments. Otherwise,
# the logic would generate a confusing "expects 0 arguments" error for an unknown
# option like this: --unknown=123.
declare -A USER_LONG_OPT_SPEC=([help]=0 [version]=0 [license]=0)
USER_LONG_OPT_SPEC+=([console-discard-stderr]=0 [console-no-close]=0)
USER_LONG_OPT_SPEC+=([terminal-type]=1 [console-title]=1 [console-icon]=1)
USER_LONG_OPT_SPEC+=([remain-open]=0 [autoclose-on-error]=0)

TERMINAL_TYPE="konsole"
CONSOLE_TITLE=""
CONSOLE_ICON=""
CONSOLE_NO_CLOSE=0
REMAIN_OPEN=0
AUTOCLOSE_ON_ERROR=0
CONSOLE_DISCARD_STDERR=0

parse_command_line_arguments "$@"

USE_KONSOLE=false
USE_XFCE4_TERMINAL=false

case "${TERMINAL_TYPE}" in
  konsole) USE_KONSOLE=true;;
  xfce4-terminal) USE_XFCE4_TERMINAL=true;;
  *) abort "Unknown terminal type \"$TERMINAL_TYPE\".";;
esac

if [ ${#ARGS[@]} -ne 1 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

CMD_ARG="${ARGS[0]}"

printf -v QUOTED_CMD_ARG "%q" "$CMD_ARG"

# We promised the user that we would run his command with "bash -c", so do not concatenate the command string
# or use 'eval' here, but issue a "bash -c" as promised.
CMD3="echo $QUOTED_CMD_ARG && bash -c $QUOTED_CMD_ARG"


if false; then
  echo "REMAIN_OPEN: $REMAIN_OPEN"
  echo "AUTOCLOSE_ON_ERROR: $AUTOCLOSE_ON_ERROR"
fi

# Some programs, like 'socat', do not terminate their error messages with an end-of-line character. Therefore,
# if we are going to prompt the user, always leave an empty line, just in case.
PRINT_EMPTY_LINE="echo"

# When prompting, the 'read' command can fail, see comment about "read error: 0: Resource temporarily unavailable" above.
ENABLE_ERROR_CHECKING="set -o errexit && set -o nounset && set -o pipefail"

if [ $REMAIN_OPEN -eq 0 ]; then

  if [ $AUTOCLOSE_ON_ERROR -eq 0 ]; then
    CMD3+="; EXIT_CODE=\"\$?\" && $PRINT_EMPTY_LINE && $ENABLE_ERROR_CHECKING && if [ \$EXIT_CODE -ne 0 ]; then while true; do read -p \"Process failed with status code \$EXIT_CODE. Type 'exit' and press Enter to exit: \" USER_INPUT; if [[ \$USER_INPUT = \"exit\" ]]; then break; fi; done; fi"
  fi

else

  if [ $AUTOCLOSE_ON_ERROR -eq 0 ]; then
    CMD3+="; EXIT_CODE=\"\$?\" && $PRINT_EMPTY_LINE && $ENABLE_ERROR_CHECKING && while true; do read -p \"Process terminated with status code \$EXIT_CODE. Type 'exit' and press Enter to exit: \" USER_INPUT; if [[ \$USER_INPUT = \"exit\" ]]; then break; fi; done"
  else
    CMD3+="; EXIT_CODE=\"\$?\" && $PRINT_EMPTY_LINE && $ENABLE_ERROR_CHECKING && if [ \$EXIT_CODE -eq 0 ]; then while true; do read -p \"Process terminated with status code \$EXIT_CODE. Type 'exit' and press Enter to exit: \" USER_INPUT; if [[ \$USER_INPUT = \"exit\" ]]; then break; fi; done; fi"
  fi

fi

printf -v CMD4 "bash -c %q" "$CMD3"

printf -v CONSOLE_ICON_QUOTED "%q" "$CONSOLE_ICON"
printf -v CONSOLE_TITLE_QUOTED "%q" "$CONSOLE_TITLE"


if $USE_KONSOLE; then

  CONSOLE_CMD="konsole --nofork"

  # Notes kept about an alternative method to set the console title with Konsole:
  #
  # Before using this option, manually create a Konsole
  # profile called "$SCRIPT_NAME", where the "Tab title
  # format" is set to %w . You may want to untick
  # global option "Show application name on the titlebar"  too.
  #
  # Code to select the right Konsole profile:
  #   CONSOLE_CMD+=" --profile $SCRIPT_NAME"
  #
  # Code to set the window title with an escape sequence:
  #  # Warning: The title does not get properly escaped here. If it contains console escape sequences,
  #  #          this will break.
  #  if [[ $CONSOLE_TITLE != "" ]]; then
  #    Later note: it is better to use printf -v CONSOLE_TITLE_QUOTED beforehand.
  #    CMD3+="printf \"%s\" \$'\\033]30;$CONSOLE_TITLE\\007' && "
  #  fi

  if [[ $CONSOLE_TITLE != "" ]]; then
    CONSOLE_CMD+=" -p tabtitle=$CONSOLE_TITLE_QUOTED"
  fi

  if [[ $CONSOLE_ICON != "" ]]; then
    CONSOLE_CMD+=" -p Icon=$CONSOLE_ICON_QUOTED"
  fi

  if [ $CONSOLE_NO_CLOSE -ne 0 ]; then
    CONSOLE_CMD+=" --noclose"
  fi

  CONSOLE_CMD+=" -e $CMD4"

fi


if $USE_XFCE4_TERMINAL; then

  CONSOLE_CMD="xfce4-terminal"

  if [[ $CONSOLE_TITLE != "" ]]; then
    CONSOLE_CMD+=" --title=$CONSOLE_TITLE_QUOTED"
  fi

  if [[ $CONSOLE_ICON != "" ]]; then
    CONSOLE_CMD+=" --icon=$CONSOLE_ICON_QUOTED"
  fi

  if [ $CONSOLE_NO_CLOSE -ne 0 ]; then
    CONSOLE_CMD+=" --hold"
  fi

  printf -v CMD5 "%q" "$CMD4"

  CONSOLE_CMD+=" --command=$CMD5"

fi


if [ $CONSOLE_DISCARD_STDERR -ne 0 ]; then
  CONSOLE_CMD+=" 2>/dev/null"
fi


if false; then
  echo "CONSOLE_CMD: $CONSOLE_CMD"
fi

eval "$CONSOLE_CMD"
