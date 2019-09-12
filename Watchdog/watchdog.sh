#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="watchdog.sh"
declare -r VERSION_NUMBER="1.02"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


check_is_positive_integer ()
{
  local STR="$1"
  local ERR_MSG_PREFIX="$2"

  local IS_NUMBER_REGEX='^[0-9]+$'

  if ! [[ $STR =~ $IS_NUMBER_REGEX ]] ; then
    abort "${ERR_MSG_PREFIX}String \"$STR\" is not a positive integer."
  fi
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This script runs a user command if the given file has not been modified in the last x seconds."
  echo
  echo "Note that the file is created, or its last modified time updated, on startup (with 'touch')."
  echo
  echo "See companion script constantly-touch-file-over-ssh.sh for a possible counterpart."
  echo "In this case, you may want to start this script on the remote host with tmux."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options> [--] <filename>  <timeout in seconds>  command <command arguments...>"
  echo
  echo "Exit status: 0 means success, any other value means failure. If the user command runs, then its exit status is returned."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
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

if (( ${#ARGS[@]} < 3 )); then
  abort "You need to specify at least 3 arguments. Run this tool with the --help option for usage information."
fi

declare -r FILENAME="${ARGS[0]}"
declare -r TIMEOUT="${ARGS[1]}"

check_is_positive_integer "$TIMEOUT" "Error parsing the timeout: "

touch -m -- "$FILENAME"

# The rest is the user command to run.
CMD_AND_ARGS=( "${ARGS[@]:2}" )

printf  -v USER_CMD  " %q"  "${CMD_AND_ARGS[@]}"

USER_CMD="${USER_CMD:1}"  # Remove the leading space.

printf -v GET_LAST_FILE_LAST_MODIFICATION_TIME_CMD  "date --reference=%q +%%s"  "$FILENAME"

printf "Watching last modification time of file \"%s\", timeout at %s seconds of age...\\n"  "$FILENAME"  "$TIMEOUT"

declare -i TIMEOUT_LEN="${#TIMEOUT}"

declare -i ITERATION=1

while true; do

  printf -v CURRENT_TIME  '%(%s)T'  -1

  FILE_LAST_MODIFICATION_TIME="$($GET_LAST_FILE_LAST_MODIFICATION_TIME_CMD)"

  FILE_AGE=$(( CURRENT_TIME - FILE_LAST_MODIFICATION_TIME ))

  if false; then
    echo "Current time: $CURRENT_TIME, file last modification time: $FILE_LAST_MODIFICATION_TIME, file age: $FILE_AGE seconds."
  fi

  if true; then
    printf "Iteration %d, file age: %*d of %d seconds (%3d%%).\\n" \
           "$ITERATION" \
           "$TIMEOUT_LEN" \
           "$FILE_AGE" \
           "$TIMEOUT" \
           "$(( FILE_AGE * 100 / TIMEOUT))"
  fi

  if (( FILE_AGE >= TIMEOUT )); then
    break
  fi

  # POSSIBLE OPTIMISATION: Do not check every second if there is still a lot of time left.
  sleep 1

  ITERATION+=1

done

printf "The file \"%s\" was not modified in the last %s seconds. Running the user command now.\\n"  "$FILENAME"  "$TIMEOUT"
echo "$USER_CMD"
eval "$USER_CMD"
exit $EXIT_CODE_SUCCESS
