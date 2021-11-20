#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2018 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool helps implement an early warning if a directory has not been updated recently as it should."
  echo
  echo "Say you have automated some back up operation. You have verified that it works."
  echo "You have tested restoring the backup once. You may even retest every month or every year."
  echo "If the backup fails, you get an automatic e-mail. Everything is covered for. Or is it?"
  echo
  echo "What if the backup fails, and the automatic e-mail fails too?"
  echo "You will certainly find out at the next manual check. But that means you did not create any backups for a month."
  echo
  echo "You cannot manually check everything every day. But you cannot really rely on automatic notifications either."
  echo "You could send an automatic e-mail notification every day, so that you notice if they stop coming."
  echo "But then you have to centralise all checks, or you will get an e-mail per host computer, which can be too many."
  echo "And such automatic system may be hard to maintain."
  echo "Besides, doing a full backup restore test every day for all backups can be an unjustifiable system load."
  echo
  echo "A good compromise can be to check daily if at least some files are still being updated at regular intervals"
  echo "at the backup destination directories. And this is what this script helps automate."
  echo "The goal is to implement a cross-check system that provides early warnings for most failures at very low cost."
  echo
  echo "Some common files are automatically ignored:"
  echo "- Any filenames starting with a dot (Unix hidden files, like .Trash-1000 or .directory)"
  echo "- Thumbs.db (Windows thumbnail cache files)"
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> <directory name>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo " --since-minutes=xx   at least one file must have changed in the last xx minutes"
  echo
  echo "Usage example:"
  echo "  ./$SCRIPT_NAME --since-minutes=\$(( 7 * 24 * 60 )) -- \"MyBackupDir\""
  echo
  echo "See SanityCheckRotatingBackup.sh for an example on how to run this script for several directories."
  echo "That example code also shows how to check that the number of files and subdirectories"
  echo "inside some directories is within the given limits."
  echo
  echo "Exit status: 0 means success, any other value means failure."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license ()
{
cat - <<EOF

Copyright (c) 2018 R. Diez

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

    since-minutes)
        if [[ $OPTARG = "" ]]; then
          abort "Option --since-minutes has an empty value.";
        fi

        SINCE_MINUTES="$OPTARG"

        if ! [[ "$SINCE_MINUTES" =~ ^[0-9]+$ ]]; then
          abort "Option --since-minutes is not a number (only digits are allowed). Its value was \"$SINCE_MINUTES\".";
        fi

        if (( SINCE_MINUTES == 0 )); then
          abort "Option --since-minutes cannot be zero.";
        fi

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

declare -r VERSION_NUMBER="1.03"
declare -r SCRIPT_NAME="CheckIfAnyFilesModifiedRecently.sh"


USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [since-minutes]=1 )

SINCE_MINUTES=0

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} < 1 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

DIRNAME="${ARGS[0]}"

if (( SINCE_MINUTES == 0 )); then
  abort "Option --since-minutes is missing."
fi


# We could make this filtering configurable.
FILTER_OPTIONS=" -type f \( -iname 'Thumbs.db' -o -name '.*' \) -prune  -o "


# The hyphen ('-') in front of the number of minutes in the 'find' command below means "less than xx minutes ago".

printf -v FIND_CMD  "find %q %s -type f  -mmin -%q  -print  -quit"  "$DIRNAME"  "$FILTER_OPTIONS"  "$SINCE_MINUTES"

if false; then
  echo "Find command: $FIND_CMD"
fi

FIRST_FILENAME="$(eval "$FIND_CMD")"

if [[ -z "$FIRST_FILENAME" ]]; then
  abort "No files where modified in the last $SINCE_MINUTES minutes under directory: $DIRNAME"
else
  if false; then
    echo "One recently-modified file was found: $FIRST_FILENAME"
  fi
fi
