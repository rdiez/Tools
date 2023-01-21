#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r VERSION_NUMBER="1.00"
declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r DESTINATION_DIR="$HOME/rdiez/temp"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2023 R. Diez - Licensed under the GNU AGPLv3

Overview:

I often need a new temporary working directory to hold files related to some task at hand.
After years creating such directories manually, I felt it was time to automate it.

The directory names this script creates look like "tmp123 - 2022-12-31 - Some Task".
The '123' part is a monotonically-increasing number, and the "Some Task" suffix
describes the contents and comes from the optional argument to this script.

For convenience, the just-created directory is opened straight away
with the system's default file explorer. Set environment variable OPEN_FILE_EXPLORER_CMD
in order to use something else other than 'xdg-open'.

All these temporary directories live at a standard location, see variable DESTINATION_DIR
in the script source code. I normally keep them somewhere under \$HOME, and not under
the system's '/tmp', where they may be automatically deleted by the OS. After all,
some matters take months to process, and I might want to look at the files say a year later.

Every now and then, I manually review the temporary directories and delete the ones
that are not worth keeping anymore. The recognisable directory name pattern
and the date help me quickly decide which directories are no longer relevant.

Occasionally, I trim, rename and move one of them to a more permanent location.
So far, this strategy has allowed me to strike a balance between quick availability
of recent information and long-term disk space requirements.

Syntax:
  $SCRIPT_NAME <optional directory name suffix>

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example:
  ./$SCRIPT_NAME "Today's Little Task"

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2023 R. Diez

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


# --------------------------------------------------

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


# --------------------------------------------------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )

parse_command_line_arguments "$@"

if false; then
  echo ARGS:
  printf -- '- %s\n' "${ARGS[@]}"
fi

declare -i CMD_LINE_ARG_COUNT="${#ARGS[@]}"

if (( CMD_LINE_ARG_COUNT == 0 )); then
  declare -r DIR_NAME_SUFFIX=""
elif (( CMD_LINE_ARG_COUNT == 1 )); then
  declare -r DIR_NAME_SUFFIX="${ARGS[0]}"
else
  abort "Too many command-line arguments. Run this tool with the --help option for usage information."
fi

pushd "$DESTINATION_DIR" >/dev/null

# The prefix must not be empty, or you then have to use filename prefix "./"
# when globbing below for Bash expansion reasons.
declare -r DIRNAME_PREFIX="tmp"

declare -r DIRNAME_REGEXP="^${DIRNAME_PREFIX}([0-9]+)"

declare -i HIGHEST_NUMBER=0
declare -i DETECTED_SEQUENCE_NUMBER

shopt -s nullglob

for FILENAME in "$DIRNAME_PREFIX"*/ ; do

  if ! [[ $FILENAME =~ $DIRNAME_REGEXP ]]; then

    if false; then
      echo "Discarding: $FILENAME"
    fi

    continue
  fi

  DETECTED_SEQUENCE_NUMBER="${BASH_REMATCH[1]}"

  if false; then
    printf "%u - %s%b" "$DETECTED_SEQUENCE_NUMBER" "$FILENAME" "\\n"
  fi

  if (( DETECTED_SEQUENCE_NUMBER > HIGHEST_NUMBER )); then
    HIGHEST_NUMBER="$DETECTED_SEQUENCE_NUMBER"
  fi

done

if false; then
  echo "HIGHEST_NUMBER: $HIGHEST_NUMBER"
fi

declare -i NEW_NUMBER=$(( HIGHEST_NUMBER + 1 ))

printf -v NEW_DIRNAME \
       "%s%d - %(%Y-%m-%d)T" \
       "$DIRNAME_PREFIX" \
       "$NEW_NUMBER"

if [ -n "$DIR_NAME_SUFFIX" ]; then
  NEW_DIRNAME+=" - $DIR_NAME_SUFFIX"
fi

echo "Creating subdirectory: $NEW_DIRNAME"

declare -r FULL_PATH="$PWD/$NEW_DIRNAME"
echo "Full path: $FULL_PATH"

mkdir -- "$NEW_DIRNAME"

if true; then

  echo
  echo "Opening the just-created subdirectory with the file explorer..."

  if is_var_set "OPEN_FILE_EXPLORER_CMD"; then
    printf -v CMD_OPEN_FOLDER  "%q -- %q"  "$OPEN_FILE_EXPLORER_CMD"  "$FULL_PATH"
  else
    printf -v CMD_OPEN_FOLDER  "xdg-open %q"  "$FULL_PATH"
  fi

  echo "$CMD_OPEN_FOLDER"
  eval "$CMD_OPEN_FOLDER"
  echo
fi

echo "Finished creating subdirectory."

popd >/dev/null
