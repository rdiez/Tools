#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.
declare -r VERSION_NUMBER="1.00"

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

This script waits until a listening TCP port is available on a remote host,
by repeatedly attempting to connect until a connection succeeds.

Syntax:
  $SCRIPT_NAME  [options...]  <hostname>  <TCP port>

  The hostname can be an IP address.

  Instead of a TCP port number, you can specify a service name like 'ssh' or 'http', provided that your
  system supports it. The list of known TCP port names is usually in configuration file /etc/services .

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

 --global-timeout=n      Set a time limit for the whole wait operation, in seconds.
                         The minimum value is 1 second.
                         By default, there is no global timeout, so this
                         script will keep retrying forever.

 --connection-timeout=n  Set a time limit for each connection attempt, in seconds.
                         The minimum value is 1 second.
                         By default, there is no connection timeout. The system will provide
                         a default which may be too long for your purposes.

 --retry-delay=n         How long the pause between connection attempts should be, in seconds.
                         The default is $RETRY_DELAY_DEFAULT seconds.
                         0 means no delay, which is often a bad idea.

The number of seconds in some options must be an integer number.

Usage example:
  \$ ./$SCRIPT_NAME  --global-timeout=60  --connection-timeout=5  example.com  80

Rationale:

  The only way to check whether a listening TCP port is reachable is to actually connect to it,
  so the server will see at least one short-lived connection which does not attempt to transfer any data.
  Normally, TCP servers do not mind, but such futile connections may show up on the server's error log.

  Specifying a connection timeout is highly recommended. Without it, you do not really know
  how long a connection attempt may take to fail. Depending on the system's configuration,
  and on the current network problems, it can take minutes.
  External tool 'timeout' is used to wrap each connection attempt,
  so it needs to be available on this system.

  The optional global timeout is implemented with the system's uptime, so it is not affected
  by eventual changes to the real-time clock.

  The global timeout may be longer than specified in practice, because this script will
  not shorten the connection timeout on the last attempt before hitting the global timeout.
  Therefore, if the connection timeout is 3 seconds, the pause between attempts is 1 second, and the
  global timeout is 5 seconds, then the global timeout will effectively be extended to 3 + 1 + 3 = 7 seconds.

  The global timeout may also be shorter than specified in practice, because this script will stop
  straightaway if the global timeout would trigger during or right after the pause between attempts.
  Therefore, if the connection timeout is 3 seconds, the pause between attempts is 1 second, and the
  global timeout is 4 seconds, then there will be only 1 connection attempt, and the global timeout
  will effectively be shortened to 3 seconds.

  The logic that handles the timeouts and the uptime has a resolution of 1 second,
  so do not expect very accurate timing. Therefore, when using a global timeout,
  there may be 1 more or 1 less connection attempt than expected.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2022 R. Diez

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
    global-timeout)
        if [[ $OPTARG = "" ]]; then
          abort "Option --global-timeout has an empty value.";
        fi
        GLOBAL_TIMEOUT="$OPTARG"
        ;;
    connection-timeout)
        if [[ $OPTARG = "" ]]; then
          abort "Option --connection-timeout has an empty value.";
        fi
        CONNECTION_TIMEOUT="$OPTARG"
        ;;
    retry-delay)
        if [[ $OPTARG = "" ]]; then
          abort "Option --retry-delay has an empty value.";
        fi
        RETRY_DELAY="$OPTARG"
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


check_is_positive_integer ()
{
  local STR="$1"
  local ERR_MSG_PREFIX="$2"

  local IS_NUMBER_REGEX='^[0-9]+$'

  if ! [[ $STR =~ $IS_NUMBER_REGEX ]] ; then
    abort "${ERR_MSG_PREFIX}String \"$STR\" is not a positive integer."
  fi
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


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  if is_tool_installed "$TOOL_NAME"; then
    return
  fi

  local ERR_MSG="Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager."

  if [[ $DEBIAN_PACKAGE_NAME != "" ]]; then
    ERR_MSG+=" For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
  fi

  abort "$ERR_MSG"
}


read_uptime_as_integer ()
{
  local PROC_UPTIME_CONTENTS
  PROC_UPTIME_CONTENTS="$(</proc/uptime)"

  local PROC_UPTIME_COMPONENTS
  IFS=$' \t' read -r -a PROC_UPTIME_COMPONENTS <<< "$PROC_UPTIME_CONTENTS"

  local UPTIME_AS_FLOATING_POINT="${PROC_UPTIME_COMPONENTS[0]}"

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


# ----- Entry point -----

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [global-timeout]=1 )
USER_LONG_OPTIONS_SPEC+=( [connection-timeout]=1 )
USER_LONG_OPTIONS_SPEC+=( [retry-delay]=1 )

GLOBAL_TIMEOUT=""
CONNECTION_TIMEOUT=""

declare -r -i RETRY_DELAY_DEFAULT=2

RETRY_DELAY="$RETRY_DELAY_DEFAULT"

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} != 2 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi


REMOTE_HOST="${ARGS[0]}"
TCP_PORT="${ARGS[1]}"


# Here we could validate REMOTE_HOST to some extent.

# We cannot check whether the TCP port is a number, because it could be a service name.
# We could do some other validation though.
if false; then
  check_is_positive_integer "$TCP_PORT" "Error in the TCP port argument: "
fi

if [ -n "$GLOBAL_TIMEOUT" ]; then
  check_is_positive_integer "$GLOBAL_TIMEOUT" "Error in the global timeout: "

  if (( GLOBAL_TIMEOUT < 1 )); then
    abort "Invalid global timeout of \"$GLOBAL_TIMEOUT\"."
  fi
fi

if [ -n "$CONNECTION_TIMEOUT" ]; then
  check_is_positive_integer "$CONNECTION_TIMEOUT" "Error in the connection timeout: "

  if (( CONNECTION_TIMEOUT < 1 )); then
    abort "Invalid connection timeout of \"$CONNECTION_TIMEOUT\"."
  fi
fi

check_is_positive_integer "$RETRY_DELAY" "Error in the retry delay: "


# Bash can connect to TCP ports by using special filenames which begin with "/dev/tcp".
# Command echo -n '' does not send or receive anything over the TCP connection.

printf -v CONNECTION_CMD \
       "echo -n '' </dev/tcp/%q/%q" \
       "$REMOTE_HOST" \
       "$TCP_PORT"

if [ -n "$CONNECTION_TIMEOUT" ]; then

  declare -r TIMEOUT_TOOL_NAME="timeout"

  verify_tool_is_installed "$TIMEOUT_TOOL_NAME" "coreutils"

  # Option '--foreground' for tool 'timeout' allows the user to interrupt the command with Ctrl+C.

  printf -v CONNECTION_CMD \
         "%q --foreground %q %q -c %q" \
         "$TIMEOUT_TOOL_NAME" \
         "$CONNECTION_TIMEOUT" \
         "$BASH" \
         "$CONNECTION_CMD"
fi


RETRY_DELAY_PLURAL_SUFFIX=""

if (( RETRY_DELAY != 1 )); then
  RETRY_DELAY_PLURAL_SUFFIX="s"
fi


if [ -n "$GLOBAL_TIMEOUT" ]; then

  GLOBAL_TIMEOUT_PLURAL_SUFFIX=""

  if (( GLOBAL_TIMEOUT != 1 )); then
    GLOBAL_TIMEOUT_PLURAL_SUFFIX="s"
  fi

  read_uptime_as_integer
  declare -r -i SYSTEM_UPTIME_BEGIN="$UPTIME"
fi


declare -i ATTEMPT_NUMBER=1

while true; do

  echo "Connecting to \"$REMOTE_HOST:$TCP_PORT\", attempt #$ATTEMPT_NUMBER..."

  if false; then
    echo "$CONNECTION_CMD"
  fi

  set +o errexit
  eval "$CONNECTION_CMD"
  EXIT_CODE="$?"
  set -o errexit

  if (( EXIT_CODE == 0 )); then
    echo "The TCP port is reachable."
    exit $EXIT_CODE_SUCCESS
  fi

  if [ -n "$GLOBAL_TIMEOUT" ]; then

    read_uptime_as_integer

    ELAPSED_TIME=$(( UPTIME - SYSTEM_UPTIME_BEGIN ))

    if false; then
      echo "Elapsed time: $ELAPSED_TIME second(s)"
    fi

    if (( ELAPSED_TIME + RETRY_DELAY >= GLOBAL_TIMEOUT )); then
      echo
      echo "Global timeout of $GLOBAL_TIMEOUT second${GLOBAL_TIMEOUT_PLURAL_SUFFIX} reached attempting to connect to \"$REMOTE_HOST:$TCP_PORT\"." >&2
      exit $EXIT_CODE_ERROR
    fi

  fi

  if (( RETRY_DELAY > 0 )); then
    echo "Retry delay of $RETRY_DELAY second${RETRY_DELAY_PLURAL_SUFFIX}..."
    sleep "$RETRY_DELAY"
  fi

  ATTEMPT_NUMBER=$(( ATTEMPT_NUMBER + 1 ))
  echo

done
