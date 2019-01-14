#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


# See companion script background.sh for more information about the 'nice' priority.
declare -i NICE_TARGET_PRIORITY=15

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r VERSION_NUMBER="1.00"
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
  echo "This tool runs the given process with a low priority and copies its output to a log file named \"$LOG_FILENAME\"."
  echo
  echo "This tool is useful in the following scenario:"
  echo "- You need to run a long process, such as copying a large number of files or recompiling"
  echo "  a big software project, on a server computer, maybe over a 'screen' or 'tmux' connection."
  echo "- The long process should not impact too much the performance of other tasks running on the server."
  echo "- You need a persistent log file with all the console output for future reference."
  echo "- You want to know how long the process took, in order to have an idea of how long it may take the next time around."
  echo "- You want all that functionality conveniently packaged in a script that takes care of all the details."
  echo "- You do not expect any interaction with the long process. Trying to read from stdin should fail."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> command <command arguments...>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Usage examples:"
  echo "  ./$SCRIPT_NAME -- echo \"Long process runs here...\""
  echo
  echo "Caveat: If you start several instances of this script, you should do it from different directories."
  echo "This script attempts to detect such a situation by creating a temporary lock file named after"
  echo "the log file and obtaining an advisory lock on it with flock (which depending on the"
  echo "underlying filesystem may have no effect)."
  echo
  echo "Exit status: Same as the command executed. Note that this script assumes that 0 means success."
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

  ELAPSED_TIME_STR+=" ($SECONDS seconds)"
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


# ----------- Entry point -----------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )

parse_command_line_arguments "$@"


if (( ${#ARGS[@]} < 1 )); then
  echo
  echo "No command specified. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
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
  echo
} >"$ABS_LOG_FILENAME"


read_uptime_as_integer
SYSTEM_UPTIME_BEGIN="$UPTIME"

set +o errexit
set +o pipefail

nice -n $NICE_DELTA -- "${ARGS[@]}" 2>&1 </dev/null | tee --append -- "$ABS_LOG_FILENAME"

# Copy the exit status array, or it will get lost when the next command executes.
declare -a CAPTURED_PIPESTATUS=( "${PIPESTATUS[@]}" )

set -o errexit
set -o pipefail

read_uptime_as_integer
SYSTEM_UPTIME_END="$UPTIME"

if [ ${#CAPTURED_PIPESTATUS[*]} -ne 2 ]; then
  abort "Internal error, unexpected pipeline status element count of ${#CAPTURED_PIPESTATUS[*]}."
fi

if [ "${CAPTURED_PIPESTATUS[1]}" -ne 0 ]; then
  abort "The 'tee' command failed."
fi

CMD_EXIT_CODE="${CAPTURED_PIPESTATUS[0]}"

if [ "$CMD_EXIT_CODE" -eq 0 ]; then
  MSG="The command finished successfully."
else
  MSG="The command failed with exit code $CMD_EXIT_CODE."
fi

get_human_friendly_elapsed_time "$(( SYSTEM_UPTIME_END - SYSTEM_UPTIME_BEGIN ))"

{
  echo
  echo "Finished running command: $CMD"
  echo "$MSG"
  echo "Elapsed time: $ELAPSED_TIME_STR"

} >>"$ABS_LOG_FILENAME"


echo
echo "Finished running command: $CMD"
echo "$MSG"
echo "Elapsed time: $ELAPSED_TIME_STR"

# Close the lock file, which releases the lock we have on it.
exec {LOCK_FILE_FD}>&-

# See companion script background.sh for more information about deleting the lock file.
rm -- "$ABS_LOCK_FILENAME"

echo "Done. Note that log file \"$ABS_LOG_FILENAME\" has been created."

exit "$CMD_EXIT_CODE"
