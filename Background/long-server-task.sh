#!/bin/bash

# Companion script background.sh has similar logic and many more comments.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -i NICE_TARGET_PRIORITY=15

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r VERSION_NUMBER="1.11"
declare -r SCRIPT_NAME="long-server-task.sh"

declare -r LOG_FILENAME="long-server-task.log"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool runs the given command with a low priority and copies its output to a log file named \"$LOG_FILENAME\"."
  echo
  echo "This tool is useful in the following scenario:"
  echo "- You need to run a long process, such as copying a large number of files or recompiling"
  echo "  a big software project, on a server computer, maybe over a 'screen' or 'tmux' connection."
  echo "- The long process should not impact too much the performance of other tasks running on the server."
  echo "- You need a persistent log file with all the console output for future reference."
  echo "- [disabled] The log file should optimise away the carriage return trick often used to update a progress indicator in place on the current console line."
  echo "- You want to know how long the process took, in order to have an idea of how long it may take the next time around."
  echo "- You want the PID of your command's parent process automatically displayed at the beginning, in order to temporarily suspend all related child processes at once with pkill, should you need the full I/O performance at this moment for something else."
  echo "- You want all that functionality conveniently packaged in a script that takes care of all the details."
  echo "- You do not expect any interaction with the long process. Trying to read from stdin should fail."
  echo
  echo "This script is often not the right solution if you are running a command on a local workstation. Consider companion script background.sh instead."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> command <command arguments...>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo " --email    sends a notification e-mail when the command has finished"
  echo " --no-console-output  places all command output only in the log file"
  echo
  echo "Usage examples:"
  echo "  ./$SCRIPT_NAME -- echo \"Long process runs here...\""
  echo
  echo "Notification e-mails are sent with S-nail. You will need a .mailrc configuration file"
  echo "in your home directory. There is a .mailrc example file next to this script."
  echo
  echo "Caveat: If you start several instances of this script, you should do it from different directories."
  echo "This script attempts to detect such a situation by creating a temporary lock file named after"
  echo "the log file and obtaining an advisory lock on it with flock (which depending on the"
  echo "underlying filesystem may have no effect)."
  echo
  echo "Exit status: Same as the command executed. Note that this script assumes that 0 means success."
  echo
  echo "Still to do: In addition to some of the items still to do in companion script background.sh, this script would benefit from an e-mail notification when finished."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license ()
{
cat - <<EOF

Copyright (c) 2019 R. Diez

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


create_lock_file ()
{
  set +o errexit
  exec {LOCK_FILE_FD}>"$ABS_LOCK_FILENAME"
  local EXIT_CODE="$?"
  set -o errexit

  if [ $EXIT_CODE -ne 0 ]; then
    abort "Cannot create or write to lock file \"$ABS_LOCK_FILENAME\"."
  fi
}


lock_lock_file ()
{
  # We are using an advisory lock here, not a mandatory one, which means that a process
  # can choose to ignore it. We always check whether the file is already locked,
  # so this type of lock is fine for our purposes.
  set +o errexit
  flock --exclusive --nonblock "$LOCK_FILE_FD"
  local EXIT_CODE="$?"
  set -o errexit

  if [ $EXIT_CODE -ne 0 ]; then
    abort "Cannot lock file \"$ABS_LOCK_FILENAME\". Is there another instance of this script ($SCRIPT_NAME) already running on the same directory?"
  fi
}


read_uptime_as_integer ()
{
  local PROC_UPTIME_CONTENTS
  PROC_UPTIME_CONTENTS="$(</proc/uptime)"

  local PROC_UPTIME_COMPONENTS
  IFS=$' \t' read -r -a PROC_UPTIME_COMPONENTS <<< "$PROC_UPTIME_CONTENTS"

  local UPTIME_AS_FLOATING_POINT=${PROC_UPTIME_COMPONENTS[0]}

  # The /proc/uptime format is not exactly documented, so I am not sure whether
  # there will always be a decimal part. Therefore, capture the integer part
  # of a value like "123" or "123.45".
  # I hope /proc/uptime never yields a value like ".12" or "12.", because
  # the following code does not cope with those.

  local REGEXP="^([0-9]+)(\\.[0-9]+)?\$"

  if ! [[ $UPTIME_AS_FLOATING_POINT =~ $REGEXP ]]; then
    abort "Error parsing this uptime value: $UPTIME_AS_FLOATING_POINT"
  fi

  UPTIME=${BASH_REMATCH[1]}
}


get_human_friendly_elapsed_time ()
{
  local -i SECONDS="$1"

  if (( SECONDS <= 59 )); then
    ELAPSED_TIME_STR="$SECONDS seconds"
    return
  fi

  local -i V="$SECONDS"

  ELAPSED_TIME_STR="$(( V % 60 )) seconds"

  V="$(( V / 60 ))"

  ELAPSED_TIME_STR="$(( V % 60 )) minutes, $ELAPSED_TIME_STR"

  V="$(( V / 60 ))"

  if (( V > 0 )); then
    ELAPSED_TIME_STR="$V hours, $ELAPSED_TIME_STR"
  fi

  printf -v ELAPSED_TIME_STR  "%s (%'d seconds)"  "$ELAPSED_TIME_STR"  "$SECONDS"
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
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
    email)
        NOTIFY_PER_EMAIL=true
        ;;
    no-console-output)
        NO_CONSOLE_OUTPUT=true
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
           fi;

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


append_all_args ()
{
  printf  -v STR  "%q " "${ARGS[@]}"
  CMD+="$STR"
}


# ----------- Entry point -----------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [email]=0 )
USER_LONG_OPTIONS_SPEC+=( [no-console-output]=0 )

NOTIFY_PER_EMAIL=false
NO_CONSOLE_OUTPUT=false

parse_command_line_arguments "$@"


if (( ${#ARGS[@]} < 1 )); then
  echo
  echo "No command specified. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
fi


declare -r S_NAIL_TOOL="s-nail"

if $NOTIFY_PER_EMAIL; then
  verify_tool_is_installed "$S_NAIL_TOOL" "s-nail"
fi


declare -i CURRENT_NICE_LEVEL
CURRENT_NICE_LEVEL="$(nice)"

if (( CURRENT_NICE_LEVEL > NICE_TARGET_PRIORITY )); then
  ABORT_MSG="Normal (unprivileged) users cannot reduce the current 'nice' level. However, the current level is $CURRENT_NICE_LEVEL, and the target level is $NICE_TARGET_PRIORITY."
  ABORT_MSG+=" Even if you are running as root, this script is actually intended to run a process with a lower priority, and reducing the 'nice' level would mean increasing its priority."
  abort "$ABORT_MSG"
fi

if (( CURRENT_NICE_LEVEL == NICE_TARGET_PRIORITY )); then
  ABORT_MSG="The current 'nice' level of $CURRENT_NICE_LEVEL already matches the target level."
  ABORT_MSG+=" However, this script is actually intended to run a process with a lower priority."
  abort "$ABORT_MSG"
fi

declare -i NICE_DELTA=$(( NICE_TARGET_PRIORITY - CURRENT_NICE_LEVEL ))


printf  -v CMD  " %q"  "${ARGS[@]}"
CMD="${CMD:1}"  # Remove the leading space.
echo "Running command with low priority: $CMD"

printf -v SUSPEND_CMD "The parent process ID is %s. You can suspend all subprocesses with this command:\\n  pkill --parent %s --signal STOP\\n"  "$BASHPID"  "$BASHPID"
printf "%s" "$SUSPEND_CMD"


LOCK_FILENAME="$LOG_FILENAME.lock"

ABS_LOG_FILENAME="$(readlink --canonicalize --verbose -- "$LOG_FILENAME")"
ABS_LOCK_FILENAME="$(readlink --canonicalize --verbose -- "$LOCK_FILENAME")"

if false; then
  echo "ABS_LOG_FILENAME: $LOG_FILENAME"
  echo "ABS_LOCK_FILENAME: $LOCK_FILENAME"
fi

create_lock_file
lock_lock_file

echo "The log file is: $ABS_LOG_FILENAME"
echo

{
  echo "Running command: $CMD"

  # Write the suspend command hint to the log file too. If that hint has scrolled out of view
  # in the current console, and is no longer easy to find, the user will probably look
  # for it at the beginning of the log file.
  printf "%s" "$SUSPEND_CMD"

  echo
} >"$ABS_LOG_FILENAME"


read_uptime_as_integer
SYSTEM_UPTIME_BEGIN="$UPTIME"

CMD="nice -n $NICE_DELTA -- "
append_all_args

if false; then
  echo "CMD: $CMD"
fi


if $NO_CONSOLE_OUTPUT; then
  # If there is no console output, it probably makes no sense to allow console input.
  declare -r DROP_STDIN=true
else
  # When running a process on a server, you do not expect any interaction, so trying to read from stdin should fail,
  # instead of forever waiting for a user who is not paying attention.
  declare -r DROP_STDIN=true
fi


if $DROP_STDIN; then
  declare -r REDIRECT_STDIN="</dev/null"
else
  declare -r REDIRECT_STDIN=""
fi

# Copy the stdout file descriptor.
exec {STDOUT_COPY}>&1

declare -r FILTER_WITH_COL=false

# The first element of this array is actually never used.
declare -a PIPE_ELEM_NAMES=("user command")

set +o errexit
set +o pipefail

if $FILTER_WITH_COL; then

  if $NO_CONSOLE_OUTPUT; then

    PIPE_ELEM_NAMES+=( "col" )

    eval "$CMD" "$REDIRECT_STDIN" 2>&1 | col -b -p -x >>"$ABS_LOG_FILENAME"

  else

    PIPE_ELEM_NAMES+=( "tee" )
    PIPE_ELEM_NAMES+=( "col" )

    eval "$CMD" "$REDIRECT_STDIN" 2>&1 | tee -- "/dev/fd/$STDOUT_COPY" | col -b -p -x >>"$ABS_LOG_FILENAME"

  fi

else

  if $NO_CONSOLE_OUTPUT; then

    eval "$CMD" "$REDIRECT_STDIN" >>"$ABS_LOG_FILENAME" 2>&1

  else

    PIPE_ELEM_NAMES+=( "tee" )

    eval "$CMD" "$REDIRECT_STDIN" 2>&1 | tee --append -- "$ABS_LOG_FILENAME"

  fi

fi

# Copy the exit status array, or it will get lost when the next command executes.
declare -a CAPTURED_PIPESTATUS=( "${PIPESTATUS[@]}" )

set -o errexit
set -o pipefail

read_uptime_as_integer
SYSTEM_UPTIME_END="$UPTIME"

# Close the file descriptor copied further above.
exec {STDOUT_COPY}>&-


declare -r -i EXPECTED_PIPE_ELEM_COUNT="${#PIPE_ELEM_NAMES[*]}"

if (( ${#CAPTURED_PIPESTATUS[*]} != EXPECTED_PIPE_ELEM_COUNT )); then
  abort "Internal error: Pipeline status element count of ${#CAPTURED_PIPESTATUS[*]} instead of the expected $EXPECTED_PIPE_ELEM_COUNT."
fi

for (( i = 1; i < EXPECTED_PIPE_ELEM_COUNT; i++ ))
do
  if [ "${CAPTURED_PIPESTATUS[$i]}" -ne 0 ]; then
   abort "The '${PIPE_ELEM_NAMES[$i]}' command in the pipe failed with exit status ${CAPTURED_PIPESTATUS[$i]}."
  fi
done


CMD_EXIT_CODE="${CAPTURED_PIPESTATUS[0]}"

declare -r LF=$'\n'

if [ "$CMD_EXIT_CODE" -eq 0 ]; then
  MSG="The command finished successfully."
  EMAIL_TITLE="$SCRIPT_NAME command succeeded"
  EMAIL_BODY="$SCRIPT_NAME command succeeded:${LF}${LF}$CMD"
else
  MSG="The command failed with exit code $CMD_EXIT_CODE."
  EMAIL_TITLE="$SCRIPT_NAME command failed"
  EMAIL_BODY="$SCRIPT_NAME command failed:${LF}${LF}$CMD"
fi

get_human_friendly_elapsed_time "$(( SYSTEM_UPTIME_END - SYSTEM_UPTIME_BEGIN ))"

{
  echo
  echo "Finished running command: $CMD"
  echo "$MSG"
  echo "Elapsed time: $ELAPSED_TIME_STR"

  if $NOTIFY_PER_EMAIL; then

    echo "Sending notification e-mail..."

    set +o errexit

    "$S_NAIL_TOOL"  -A "automatic-email-notification"  -s "$EMAIL_TITLE"  -.  automatic-email-notification-recipient-addr <<< "$EMAIL_BODY"

    EMAIL_EXIT_CODE="$?"
    set -o errexit

    if (( EMAIL_EXIT_CODE == 0 )); then
      echo "Finished sending notification e-mail."
    fi

    # Sending an e-mail can fail for many reasons, like temporary network or mail server problems.
    # If that happens, it is not clear whether this script should fail.
    # At the moment, it does not. If the script were to fail in the future,
    # make sure that this failure does not prevent the lock file from being removed below.

  fi

} 2>&1 </dev/null | tee --append -- "$ABS_LOG_FILENAME"


# Close the lock file, which releases the lock we have on it.
exec {LOCK_FILE_FD}>&-

# See companion script background.sh for more information about deleting the lock file.
rm -- "$ABS_LOCK_FILENAME"

echo "Done. Note that log file \"$ABS_LOG_FILENAME\" has been created."

exit "$CMD_EXIT_CODE"
