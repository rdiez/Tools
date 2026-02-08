#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.00"

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


declare -r EMACS_BASE_PATH_ENV_VAR_NAME="EMACS_BASE_PATH"


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2026 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool helps you call an arbitrary Emacs Lisp function with arbitrary arguments from the shell."
  echo
  echo "The target Emacs instance must already be running, and must have started the Emacs server, as this script uses the '$EMACS_CLIENT_FILENAME_ONLY' tool. See Emacs' function 'server-start' for details. I tried to implement this script so that it would start Emacs automatically if not already there, but I could not find a clean solution. See this script's source code for more information."
  echo
  echo "Emacs version 30.1 or later is required, as this script uses 'server-eval-args-left'."
  echo
  echo "If you Emacs is not on the PATH, set environment variable $EMACS_BASE_PATH_ENV_VAR_NAME. This script will then use \${$EMACS_BASE_PATH_ENV_VAR_NAME}/bin/$EMACS_CLIENT_FILENAME_ONLY."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> lisp-function-name <funtion arguments...>"
  echo
  echo "Usage example:"
  echo "  $SCRIPT_NAME -- message-box \"Test args: %s %s\" \"arg1\" \"arg2\""
  echo
  echo "You can specify the following options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo " --suppress-output  When successful, do not show the result of the Lisp function, which is often just nil."
  echo " --show-cmd         Shows the '$EMACS_CLIENT_FILENAME_ONLY' command which this script builds and runs."
  echo
  echo "Exit status: 0 means success, anything else is an error."
  echo
  echo "CAVEAT: A function argument cannot be an empty string. This is a bug in Emacs 30.x."
  echo "        For more information see the following bug report:"
  echo "        https://debbugs.gnu.org/cgi/bugreport.cgi?bug=80356"
  echo
  echo "Feedback: Please send feedback to rdiez-tools at rd10.de"
  echo
}


display_license()
{
cat - <<EOF

Copyright (c) 2026 R. Diez

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
    suppress-output)
      SUPRESS_OUTPUT_SPECIFIED=true;;
    show-cmd)
      SHOW_CMD_SPECIFIED=true;;

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

           # If all the command-line arguments implemented exit immediately,
           # then you get a ShellCheck warning here.
           # shellcheck disable=SC2317
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


# ------ Entry Point (only by convention) ------

declare -r EMACS_CLIENT_FILENAME_ONLY="emacsclient"

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [suppress-output]=0 )
USER_LONG_OPTIONS_SPEC+=( [show-cmd]=0 )

SUPRESS_OUTPUT_SPECIFIED=false
SHOW_CMD_SPECIFIED=false

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} < 1 )); then
  abort "No Emacs Lisp function name specified. Run this tool with the --help option for usage information."
fi


if is_var_set "$EMACS_BASE_PATH_ENV_VAR_NAME"; then
  declare -r EMACS_CLIENT="${!EMACS_BASE_PATH_ENV_VAR_NAME}/bin/$EMACS_CLIENT_FILENAME_ONLY"
else
  declare -r EMACS_CLIENT="$EMACS_CLIENT_FILENAME_ONLY"
fi

if ! is_tool_installed "$EMACS_CLIENT"; then
  abort "Executable \"$EMACS_CLIENT\" not found."
fi


declare -r LISP_FUNCTION_NAME="${ARGS[0]}"

# Here we could validate that LISP_FUNCTION_NAME honours the Emacs Lisp function name rules.

LISP_CODE="("
LISP_CODE+="$LISP_FUNCTION_NAME"


for ((I=1; I<${#ARGS[@]}; ++I)); do

  # This bug should be fixed in the upcoming Emacs version 31.
  if [ -z "${ARGS[$I]}" ]; then
    abort "A function argument is empty. See the help text for more information about this limitation."
  fi

  LISP_CODE+=" (pop server-eval-args-left)"
done

LISP_CODE+=")"


if false; then
  echo "Lisp code for emacsclient --eval: $LISP_CODE"
fi


# About why an Emacs server instance must already be running:
#
# The 'emacsclient' tool has an '--alternate-editor' argument that can start a new Emacs instance
# if an existing one is not reachable over the server socket. The trouble is, as of version 24.3,
# the new Emacs instance is not started with the --eval argument, so this script breaks.
#
# On this web page I found the following workaround:
#   http://www.emacswiki.org/emacs/EmacsClient
# If you start emacsclient with argument '--alternate-editor="/usr/bin/false"', it will fail,
# and then you can start Emacs with the --eval argument. Caveats are:
# - emacsclient prints ugly error messages.
# - emacsclient does not document that its exit code will indicate a failure if --alternate-editor fails.
# - There is no way to tell whether something else failed.
# - Starting "emacs --eval" is problematic. This script would then wait forever for the new Emacs instance to terminate.
#   If Emacs were to be started in the background, there is no way to find out if it failed.
# After considering all the options, I decided to keep this script clean and simple, at the cost
# of demanding an existing Emacs server. For serious Emacs users, that is the most common scenario anyway.

CMD="${EMACS_CLIENT@Q}"

if false; then
  # This argument does not seem to have any effect, at least for our usage scenario:
  # -q, --quiet  Don't display messages on success
  CMD+=" --quiet"
fi

if $SUPRESS_OUTPUT_SPECIFIED; then
  # This suppresses outputting the result of the Lisp function, which is often just nil.
  # It does not prevent showing an error message on failure.
  CMD+=" --suppress-output"
fi

CMD+=" --eval ${LISP_CODE@Q}"

if (( ${#ARGS[@]} > 1 )); then

  printf -v QUOTED_ARGS " %q" "${ARGS[@]:1}"

  CMD+=" $QUOTED_ARGS"

fi

if $SHOW_CMD_SPECIFIED; then
  echo "$CMD"
fi

set +o errexit

# Possible optimisation: If we are not doing anything else afterwards, we could do 'exec' here.
eval "$CMD"

declare -r -i EMACS_CLIENT_EXIT_CODE="$?"

set -o errexit

if (( EMACS_CLIENT_EXIT_CODE != 0 )); then
  # abort "emacsclient failed with exit code $EMACS_CLIENT_EXIT_CODE."
  exit $EMACS_CLIENT_EXIT_CODE
fi
