#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


VERSION_NUMBER="1.02"
SCRIPT_NAME="CheckVersion.sh"

EXIT_CODE_SUCCESS=0
EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

Overview:

This scripts helps generate an error or warning message if a given version number
is different/less than/etc. compared to a reference version number.

Syntax:
  $SCRIPT_NAME [options...] [--] <version name> <detected version> <comparator> <reference version>

Possible comparators are: <, <=, >, >=, ==, != and their aliases lt, le, gt, ge, eq, ne.

Version numbers must be a sequence of integer numbers separated by periods, like "1.2.3".
Version components are compared numerically, so version "01.002.3.0.0" is equivalent to the example above,
and versions "1.5" and "1.2.3.4" are considered greater.

Options:
 --help     displays this help text
 --version  displays this tool's version number (currently $VERSION_NUMBER)
 --license  prints license information
 --warning-stdout  prints a warning to stdout but still exit with status code $EXIT_CODE_SUCCESS (success)
 --warning-stderr  prints a warning to stderr but still exit with status code $EXIT_CODE_SUCCESS (success)
 --result-as-text  prints "true" or "false" depending on whether the condition succeeds or fails

Usage example:
  ./$SCRIPT_NAME "MyTool" "1.2.0" ">=" "1.2.3"  # This check fails, so it prints an error message.

Exit status:
Normally, $EXIT_CODE_SUCCESS means success, and any other value means error,
but some of command-line switches above change this behaviour.

Capturing version numbers:
Some tools make it easy to capture their version numbers. For example, GCC has switch "-dumpversion",
which just prints its major version number without any decoration (like "4.8"). In the case of GCC,
that switch is actually poorly implemented, because it only gives you the major version number, so
you may want to use switch "--version" instead, which prints the complete version number. Unfortunately,
the version string is not alone anymore, you get a text line like "gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2"
followed by some software license text. Many tools have no way to print an isolated version number.
For example, OpenOCD prints a line (to stderr!) like "Open On-Chip Debugger 0.7.0 (2013-10-22-08:31)".

Therefore, you often have to resort to unreliable text parsing. It is important to remember that
the version message is normally not rigidly specified, so it could change in the future and break
your version check script, or worse, make it always succeed without warning.

If you are writing software, please include a way to cleanly retrieve an isolated version number,
so that it is easy to parse reliably.

This is an example in bash of how you could parse and check OpenOCD's version string:

  OPENOCD_VERSION_TEXT="\$("openocd" --version 2>&1)"

  VERSION_REGEX="([[:digit:]]+.[[:digit:]]+.[[:digit:]]+)"

  if [[ \$OPENOCD_VERSION_TEXT =~ \$VERSION_REGEX ]]; then
    VERSION_NUMBER_FOUND="\${BASH_REMATCH[1]}"
  else
    abort "Could not determine OpenOCD's version number."
  fi

  $SCRIPT_NAME "OpenOCD" "\$VERSION_NUMBER_FOUND" ">=" "0.8.0"


Version history:
1.00, Sep 2014: First release.
1.02, Sep 2014: Fixed versions with leading '0' being interpreted as octal numbers. Added != operator.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2014 R. Diez

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


parse_version ()
{
  local VERSION_STR="$1"
  local VERSION_NAME="$2"
  local RET_ARRAY_NAME="$3"

  if [[ $VERSION_STR == "" ]] ; then
    abort "Error parsing version string \"$VERSION_STR\" of \"$VERSION_NAME\": The version string is empty."
  fi

  local SEPARATOR="."


  # If the version string starts or ends with the version separator, bash will not complain when splitting the string,
  # so we need to check those error cases beforehand.

  local STARTS_WITH_SEPARATOR_REGEX="^\\$SEPARATOR"
  if [[ $VERSION_STR =~ $STARTS_WITH_SEPARATOR_REGEX ]] ; then
    abort "Error parsing version string \"$VERSION_STR\" of \"$VERSION_NAME\": The version string starts with the version separator."
  fi

  local ENDS_WITH_SEPARATOR_REGEX="\\$SEPARATOR\$"
  if [[ $VERSION_STR =~ $ENDS_WITH_SEPARATOR_REGEX ]] ; then
    abort "Error parsing version string \"$VERSION_STR\" of \"$VERSION_NAME\": The version string ends with the version separator."
  fi


  local IFS="$SEPARATOR"
  declare -a VERSION_COMPONENTS=($VERSION_STR)

  local VERSION_COMPONENT_COUNT=${#VERSION_COMPONENTS[@]}

  if false; then
    IFS=","
    echo "VERSION_COMPONENT_COUNT: $VERSION_COMPONENT_COUNT, VERSION_COMPONENTS: ${VERSION_COMPONENTS[*]}"
  fi

  if [ $VERSION_COMPONENT_COUNT -lt 1 ]; then
    abort "Error parsing version string \"$VERSION_STR\" of \"$VERSION_NAME\"."
  fi

  local IS_NUMBER_REGEX='^[0-9]+$'

  local versionComponent
  for versionComponent in "${VERSION_COMPONENTS[@]}"
  do
    if ! [[ $versionComponent =~ $IS_NUMBER_REGEX ]] ; then
      abort "Error parsing version string \"$VERSION_STR\" of \"$VERSION_NAME\": Version component \"$versionComponent\" is not a positive integer."
    fi
  done

  eval "declare -ag $RET_ARRAY_NAME=(\"\${VERSION_COMPONENTS[@]}\")"
}


# This routine uses global variables VERSION_COMPONENTS_1 and VERSION_COMPONENTS_2,
# for passing arrays as function arguments is hard.

compare_versions()
{
  local VERSION_NAME="$1"
  local VERSION_COMPARATOR="$2"
  local RESULT_VAR="$3"

  local VERSION_COMPONENT_COUNT_1=${#VERSION_COMPONENTS_1[@]}
  local VERSION_COMPONENT_COUNT_2=${#VERSION_COMPONENTS_2[@]}

  local ITERATION_COUNT="$(( VERSION_COMPONENT_COUNT_1 >= VERSION_COMPONENT_COUNT_2 ? VERSION_COMPONENT_COUNT_1 : VERSION_COMPONENT_COUNT_2))"

  eval "$RESULT_VAR=no"

  local -i INDEX
  local C1STR
  local C2STR
  local -i C1
  local -i C2

  for (( INDEX=0; INDEX < $ITERATION_COUNT; INDEX++ )) do

    if [ $INDEX -lt $VERSION_COMPONENT_COUNT_1 ]; then
      C1STR="${VERSION_COMPONENTS_1[$INDEX]}"
      # Remove any leading zeros, by telling bash to parse the numbers in base 10.
      # Otherwise, a leading zero will make bash interpret the numbers as octal integers.
      C1="$(( 10#$C1STR ))"
    else
      C1=0
    fi

    if [ $INDEX -lt $VERSION_COMPONENT_COUNT_2 ]; then
      C2STR="${VERSION_COMPONENTS_2[$INDEX]}"
      # Remove any leading zeros, by telling bash to parse the numbers in base 10.
      # Otherwise, a leading zero will make bash interpret the numbers as octal integers.
      C2="$(( 10#$C2STR ))"
    else
      C2=0
    fi

    # echo "INDEX: $INDEX, C1: $C1, C2: $C2"

    if [ $C1 -lt $C2 ]; then
      eval "$RESULT_VAR=less_than"
      return
    fi

    if [ $C1 -gt $C2 ]; then
      eval "$RESULT_VAR=greater_than"
      return
    fi

  done

  eval "$RESULT_VAR=equal_to"
}


# --------------------------------------------------

# The way command-line arguments are parsed below was originally described on the following page,
# although I had to make a couple of amendments myself:
#   http://mywiki.wooledge.org/ComplexOptionParsing

# Use an associative array to declare how many arguments a long option expects.
# Long options that aren't listed in this way will have zero arguments by default.
declare -A MY_LONG_OPT_SPEC=()

# The first colon (':') means "use silent error reporting".
# The "-:" means an option can start with '-', which helps parse long options which start with "--".
MY_OPT_SPEC=":-:"

WARNING_STDOUT=false
WARNING_STDERR=false
RESULT_AS_TEXT=false

while getopts "$MY_OPT_SPEC" opt; do
  while true; do
    case "${opt}" in
      -)  # OPTARG is name-of-long-option or name-of-long-option=value
          if [[ "${OPTARG}" =~ .*=.* ]]  # With this --key=value format, only one argument is possible. See also below.
          then
              opt=${OPTARG/=*/}
              OPTARG=${OPTARG#*=}
              ((OPTIND--))
          else  # With this --key value1 value2 format, multiple arguments are possible.
              opt="$OPTARG"
              OPTARG=(${@:OPTIND:$((MY_LONG_OPT_SPEC[$opt]))})
          fi
          ((OPTIND+=MY_LONG_OPT_SPEC[$opt]))
          continue  # Now that opt/OPTARG are set, we can process them as if getopts would have given us long options.
          ;;
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
      warning-stdout)
          WARNING_STDOUT=true
          ;;
      warning-stderr)
          WARNING_STDERR=true
          ;;
      result-as-text)
          RESULT_AS_TEXT=true
          ;;
      *)
          if [[ ${opt} = "?" ]]; then
            abort "Unknown command-line option \"$OPTARG\"."
          else
            abort "Unknown command-line option \"${opt}\"."
          fi
          ;;
    esac

    break
  done
done


shift $(( OPTIND - 1 ))

if [ $# -ne 4 ]; then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi


VERSION_NAME="$1"
DETECTED_VERSION="$2"
VERSION_COMPARATOR="$3"
REFERENCE_VERSION="$4"


# Removing leading and trailing whitespace needs extended globbing.
shopt -s extglob

# Remove leading whitespace.
DETECTED_VERSION="${DETECTED_VERSION##+([[:space:]])}"
# Remove trailing whitespace.
DETECTED_VERSION="${DETECTED_VERSION%%+([[:space:]])}"

# Remove leading whitespace.
REFERENCE_VERSION="${REFERENCE_VERSION##+([[:space:]])}"
# Remove trailing whitespace.
REFERENCE_VERSION="${REFERENCE_VERSION%%+([[:space:]])}"

shopt -u extglob


case "$VERSION_COMPARATOR" in
  (">") ;;
  (">=") ;;
  ("<") ;;
  ("<=") ;;
  ("==") ;;
  ("!=") ;;
  ("gt") VERSION_COMPARATOR=">";;
  ("ge") VERSION_COMPARATOR=">=";;
  ("lt") VERSION_COMPARATOR="<";;
  ("le") VERSION_COMPARATOR="<=";;
  ("eq") VERSION_COMPARATOR="==";;
  ("ne") VERSION_COMPARATOR="!=";;
  (*) abort "Unknown comparator \"$VERSION_COMPARATOR\".";;
esac


parse_version "$DETECTED_VERSION" "$VERSION_NAME" VERSION_COMPONENTS_1
parse_version "$REFERENCE_VERSION" "reference version" VERSION_COMPONENTS_2

compare_versions "$VERSION_NAME" "$VERSION_COMPARATOR" "COMPARISON_RESULT"

CASE_VAR="$VERSION_COMPARATOR $COMPARISON_RESULT"

case "$CASE_VAR" in
  ("> less_than") RESULT="no";;
  ("> greater_than") RESULT="yes";;
  ("> equal_to") RESULT="no";;

  (">= less_than") RESULT="no";;
  (">= greater_than") RESULT="yes";;
  (">= equal_to") RESULT="yes";;

  ("< less_than") RESULT="yes";;
  ("< greater_than") RESULT="no";;
  ("< equal_to") RESULT="no";;

  ("<= less_than") RESULT="yes";;
  ("<= greater_than") RESULT="no";;
  ("<= equal_to") RESULT="yes";;

  ("== less_than") RESULT="no";;
  ("== greater_than") RESULT="no";;
  ("== equal_to") RESULT="yes";;

  ("!= less_than") RESULT="yes";;
  ("!= greater_than") RESULT="yes";;
  ("!= equal_to") RESULT="no";;

  (*) abort "Internal error, invalid case \"$CASE_VAR\".";;
esac


if $RESULT_AS_TEXT; then
  if [[ $RESULT == "yes" ]]; then
    echo "true"
  else
    echo "false"
  fi
  exit $EXIT_CODE_SUCCESS
fi


if [[ $RESULT == "yes" ]]; then
  exit $EXIT_CODE_SUCCESS
fi


MSG="Version \"$DETECTED_VERSION\" of \"$VERSION_NAME\" does not fulfil condition \"$VERSION_COMPARATOR\" against the reference version \"$REFERENCE_VERSION\"."

if $WARNING_STDOUT; then
  echo "Warning: $MSG"
fi

if $WARNING_STDERR; then
  echo "Warning: $MSG" >&2
fi

if ! $WARNING_STDOUT; then
  if ! $WARNING_STDERR; then
    echo "Error: $MSG" >&2
    exit $EXIT_CODE_ERROR
  fi
fi

exit $EXIT_CODE_SUCCESS
