#!/bin/bash

# Start this script with --help for more information.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r VERSION_NUMBER="1.00"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.


abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


add_gdb_arg ()
{
  GDB_CMD+=" $1"
}


add_gdb_echo_cmd ()
{
  local MSG="$1"

  local QUOTED
  printf -v QUOTED "%q" "$MSG"
  add_gdb_arg "--eval-command=\"echo > $QUOTED\\n\""
}


add_gdb_cmd ()
{
  local CMD="$1"

  add_gdb_echo_cmd "$CMD"
  local QUOTED
  printf -v QUOTED "%q" "$CMD"
  add_gdb_arg "--eval-command=$QUOTED"
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2025 R. Diez - Licensed under the GNU AGPLv3

Overview:

If you develop for Microsoft Windows with MinGW-w64 on Linux, you will probably want to debug
your application with Wine using gdbserver and a cross-debugger like x86_64-w64-mingw32-gdb.
Starting the debugger in this scenario can be tricky, so this script should help.

First all, amend variables GDBSERVER_PATH and RUN_IN_NEW_CONSOLE_TOOL in this script
as necessary for your system. You may want to change GDBSERVER_TCP_PORT too.

Syntax:
  $SCRIPT_NAME <options...> [--] <unix-path-to-windows-exe>  ...arguments for the exe...

Options:

 --debugger=<gdb or ddd> Choose the debuger to use. The default is 'gdb' for plain GDB.
                         With 'ddd', the DDD GUI will be launched with GDB underneath.
                         You need to install DDD on your system beforehand.

 --add-breakpoint=<routine name>  Add a breakpoint before starting the application.
                                  This option can be specified multiple times.

 --debug-from-the-start  Stop the application right after it starts.

 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Exit status: 0 means success. Any other value means error.

How to achieve faster application start-up:
Starting applications with Wine can take some time. The following command will make it faster by caching state:

  StartDetached.sh wineserver --persistent

You will find helper script StartDetached.sh is in the same repository as this script,
or just use any other standard method to start "wineserver --persistent" as a background
daemon/service on system start-up or user logon.

Feedback: Please send feedback to rdiez-tools at rd10.de

EOF
}


display_license ()
{
cat - <<EOF

Copyright (c) 2025 R. Diez

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

    debug-from-the-start) DEBUG_FROM_THE_START_SPECIFIED=true;;

    debugger)  if [[ $OPTARG = "" ]]; then
                 abort "The --terminal-type option has an empty value.";
               fi
               DEBUGGER_TYPE="$OPTARG"
               ;;

    add-breakpoint)
        if [[ $OPTARG = "" ]]; then
          abort "The --add-breakpoint option has an empty value."
        fi
        BREAKPOINTS+=("$OPTARG")
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


check_background_job_still_running ()
{
  # Unfortunately, Bash does not provide a timeout option for the 'wait' command, or any other
  # option for it that only checks the job status without blocking.
  #
  # In order to check whether a child process is still alive, we could use something like this:
  #
  #   kill -0 "$CHILD_PID"
  #
  # However, that is unreliable, because the system can reuse PIDs at any point in time.
  # Using a Bash job spec like this does not help either:
  #
  #   kill -0 %123
  #
  # The trouble is, the internal job table is apparently not updated in non-interactive shells
  # until you execute a 'jobs' command. If the job has finished, attempting to reference
  # its job spec will succeed only once the next time around. The job spec will then be dropped,
  # and any subsequence reference to it will fail, in the best case, or will reference
  # some other later job in the worst scenario.
  #
  # Furthermore, parsing the output from 'jobs' is not easy either. Here are some examples:
  #
  #  [1]+  Done                    my command
  #  [2]-  Done(1)                 my command
  #  [3]   Terminated              my command
  #  [4]   Running                 my command
  #  [5]   Stopped                 my command
  #  [6]   Killed                  my command
  #  [7]   Terminated              my command
  #  [8]   User defined signal 1   my command
  #  [9]   Profiling timer expired my command
  #
  # '+' means it is the "current" job. '-' means it is the "previous" job.
  # 'Done' means an exit code of 0. 'Done(1)' means the process terminated with an exit status of 1.
  # 'Terminated' means SIGTERM, 'Killed' means SIGKILL, 'User defined signal 1' means SIGUSR1,
  # and 'Profiling timer expired' menas SIGPROF.
  #
  # All of the above is from empirical testing. As far as I can see, it is not documented.
  # Therefore, I assume that it can change in any future version. Those messages could
  # for example be translated in non-English locales.
  #
  # Therefore, attempting to parse the ouput is not a good idea.
  #
  # The workaround I have implemented is as follows: if 'jobs %n' fails, the job is not running
  # anymore, and the reason why not was reported in the last successful invocation of 'jobs %n'.
  # The downside is that the caller will realise that the job has finished on the next call
  # to this routine. That is, there is a delay of one routine call.

  local JOB_SPEC="$1"

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
  local JOBS_OUTPUT_FILENAME
  JOBS_OUTPUT_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.txt")"
  if false; then
    echo "JOBS_OUTPUT_FILENAME: $JOBS_OUTPUT_FILENAME"
  fi

  set +o errexit

  # We cannot capture the output as usual like this:
  #   $(jobs $JOBS_SPEC)
  # The reason is that $() runs the command in a subshell, and changes to the internal job table
  # are apparently not propagated to the parent shell instance.
  # The workaround is to use a temporary file.
  jobs "$JOB_SPEC" >"$JOBS_OUTPUT_FILENAME"

  local JOBS_EXIT_CODE="$?"

  set -o errexit

  local JOBS_OUTPUT
  JOBS_OUTPUT="$(<"$JOBS_OUTPUT_FILENAME")"

  rm -- "$JOBS_OUTPUT_FILENAME"

  if (( JOBS_EXIT_CODE != 0 )); then
    # Let the user see what 'jobs' printed, if anything. It will come after stderr,
    # but it is better than nothing.
    printf "%s" "$JOBS_OUTPUT"

    MSG="The background child process failed to initialise or is no longer running."
    if [ -n "$LAST_JOB_STATUS" ]; then
      MSG+=" Its job result was: "
      MSG+="$LAST_JOB_STATUS"
    fi

    abort "$MSG"
  fi

  LAST_JOB_STATUS="$JOBS_OUTPUT"
}


parse_job_id ()
{
  local JOBS_OUTPUT="$1"

  local REGEXP="^\\[([0-9]+)\\]"

  if ! [[ $JOBS_OUTPUT =~ $REGEXP ]]; then
    local ERR_MSG
    printf -v ERR_MSG "Cannot parse this output from 'jobs' command:\\n%s" "$JOBS_OUTPUT"
    abort "$ERR_MSG"
  fi

  CAPTURED_JOB_SPEC="%${BASH_REMATCH[1]}"

  if false; then
    echo "CAPTURED_JOB_SPEC: $CAPTURED_JOB_SPEC"
  fi
}


# ------ Entry Point (only by convention) ------

declare -r TARGET_ARCH="x86_64-w64-mingw32"

declare -r WINE_TOOL_NAME="wine64"

# Ubuntu/Debian package name for the cross-GDB: gdb-mingw-w64
declare -r GDB_NAME="$TARGET_ARCH-gdb"

# Ubuntu/Debian package name for gdbserver.exe: gdb-mingw-w64-target
declare -r GDBSERVER_NAME="gdbserver.exe"
# On Ubuntu/Debian, there are 2 versions of gdbserver.exe, for 32 and 64 bits,
# and they are not in the PATH. Unfortunately, they are called exactly the same.
# Here we select the right one.
declare -r GDBSERVER_PATH="/usr/share/win64/$GDBSERVER_NAME"

declare -r GDBSERVER_HOST="localhost"

# Choose some TCP port number unlikely to be used on this computer for gdbserver listening purposes.
declare -r GDBSERVER_TCP_PORT="12345"

# If this tool is not in your PATH, amend this variable as necessary.
# You will find this tool in the same repository as this script.
declare -r RUN_IN_NEW_CONSOLE_TOOL="run-in-new-console.sh"


USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [debugger]=1 )
USER_LONG_OPTIONS_SPEC+=( [add-breakpoint]=1 )
USER_LONG_OPTIONS_SPEC+=( [debug-from-the-start]=0 )

DEBUG_FROM_THE_START_SPECIFIED=false
DEBUGGER_TYPE="gdb"
declare -a BREAKPOINTS=()

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} < 1 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

WINDOWS_EXE_FILE_PATH="${ARGS[0]}"
shift

case "$DEBUGGER_TYPE" in
  ddd) : ;;
  gdb) : ;;
  *) abort "Unknown debugger type \"$DEBUGGER_TYPE\" specified with option '--debugger'."
esac

# If GDB cannot find the executable file, it will print an error, but it will not stop.
# Therefore, manually check here whether the file does exist.
WINDOWS_EXE_FILE_PATH_ABS="$(readlink  --verbose  --canonicalize-existing -- "$WINDOWS_EXE_FILE_PATH")"

# gdbserver version 10.2 cannot cope with spaces in the executable filename.
# I tried passing both Unix-style and Windows-style paths, with and without double quotes, to no avail:
# if it does not fail, then it breaks the filename at the spaces and passes several command-line arguments
# to the child process, instead of automatically quoting the filename so that it gets parsed later
# as a single argv[0] argument. I tested it by printing what GetCommandLineW() returns.
# Only the first argument has this problem all arguments beginning with argv[1]
# are automatically surrounded with double quotes.
# One work-around we could implement here is to change the working directory to the location
# where the executable file resides, but that does not help if the .exe filename itself contains spaces.
declare -r DETECT_WHITESPACE_REGEXP="[[:space:]]"

if [[ $WINDOWS_EXE_FILE_PATH_ABS =~ $DETECT_WHITESPACE_REGEXP ]]; then
  abort "The absolute path to the executable file \"$WINDOWS_EXE_FILE_PATH_ABS\" contains whitespace, and gdbserver cannot cope with it."
fi


CMD_LINE_ARGS=""

declare -r -i ARGS_ELEM_COUNT=${#ARGS[@]}

# Note that we skip the first index.

for (( INDEX = 1 ; INDEX < ARGS_ELEM_COUNT; ++INDEX )); do
  # I am not sure whether the quoting rules in Bash are the same as in GDB,
  # or at least compatible enough. It does work for arguments which contain spaces.
  printf -v TMP "%q" "${ARGS[$INDEX]}"
  CMD_LINE_ARGS+=" $TMP"
done


# ------ Start gdbserver in the background ------

# If a previous gdbserver is still running, the new instance will fail with an error message
# stating that it cannot bind to the given TCP port. In order to generate a better
# error message, we could attempt here to connect to GDBSERVER_HOST:GDBSERVER_TCP_PORT.
# If a connection succeeds, then a previous gdbserver is still around.
# Script WaitForTcpPort.sh has example code about how to connect to a TCP port with Bash.

echo "Starting gdbserver..."

# I haven't actually seen any clear advantage yet about using gdbserver's '--multi' mode.
declare SHOULD_START_GDBSERVER_IN_MULTI_MODE=true

GDBSERVER_CMD_PREFIX=""

if true; then
  # Prevent warnings like this:
  #   05dc:fixme:font:get_name_record_codepage encoding 20 not handled, platform 1.
  GDBSERVER_CMD_PREFIX+="WINEDEBUG=fixme-font "
fi

if $SHOULD_START_GDBSERVER_IN_MULTI_MODE; then

  # Option --once is not really necessary, but it help minimise the chances
  # that gdbserver will be left behind if this script is unexpectedly killed.

  printf -v GDBSERVER_CMD \
         "%s%q  %q  --once --multi  %q:%q" \
         "$GDBSERVER_CMD_PREFIX" \
         "$WINE_TOOL_NAME" \
         "$GDBSERVER_PATH" \
         "$GDBSERVER_HOST" \
         "$GDBSERVER_TCP_PORT"

else

  # gdbserver seems to have no problems with Unix-style paths.
  # Just in case, the code below also shows how to convert
  # the executable path to Windows style.
  declare -r SHOULD_GDBSERVER_GET_UNIX_STYLE_PATH=true

  if $SHOULD_GDBSERVER_GET_UNIX_STYLE_PATH; then
    EXE_PATH_FOR_GDBSERVER="$WINDOWS_EXE_FILE_PATH_ABS"
  else
    WINDOWS_EXE_FILE_PATH_ABS_WIN="$(winepath --windows "$WINDOWS_EXE_FILE_PATH_ABS")"
    EXE_PATH_FOR_GDBSERVER="$WINDOWS_EXE_FILE_PATH_ABS_WIN"
  fi

  printf -v GDBSERVER_CMD \
         "%s%q  %q  --once %q:%q \"%s\"%s" \
         "$GDBSERVER_CMD_PREFIX" \
         "$WINE_TOOL_NAME" \
         "$GDBSERVER_PATH" \
         "$GDBSERVER_HOST" \
         "$GDBSERVER_TCP_PORT" \
         "$EXE_PATH_FOR_GDBSERVER" \
         "$CMD_LINE_ARGS"
fi

echo "$GDBSERVER_CMD"
echo
eval "$GDBSERVER_CMD" &


# This first check will probably always succeed. If the child process has terminated,
# we will find out the next time around. We are doing an initial check
# in order to extract the exact job ID. Bash provides no other way to
# get the job spec, as far as I can tell. Always using the "last job" spec %%
# is risky, because something else may start another job in the meantime.
LAST_JOB_STATUS=""
check_background_job_still_running %%
parse_job_id "$LAST_JOB_STATUS"
GDBSERVER_JOB_SPEC="$CAPTURED_JOB_SPEC"


# ------ Start GDB in a separate console ------

GDB_CMD=""

if [[ $DEBUGGER_TYPE = "ddd" ]]; then

  GDB_CMD+="ddd --debugger \"$GDB_NAME\""

  # If we don't turn confirmation off for dangerous operations, then we cannot just close
  # DDD's window, we have to click on an OK button first. It's a shame that there is no option
  # in DDD to suppress confirmation on exit.
  add_gdb_cmd "set confirm off"

else

  printf -v TMP "%q" "$GDB_NAME"

  GDB_CMD+="$TMP"

  # Whether you like the TUI mode is your personal preference.
  #
  # In TUI mode, you cannot scroll the command window to see previous output. This is a serious inconvenience,
  # so you may need to disable TUI every now and then.
  #
  # Some GDB versions may have been built without TUI support.
  #
  # Disabling TUI from inside GDB with command "tui disable" makes my GDB 9.2 suddenly quit,
  # but that seems to work better with GDB 10.2.
  declare -r ENABLE_TUI=true

  if $ENABLE_TUI; then
    add_gdb_arg "--tui"
  fi

  # If the new console window happens to open with a small size, you'll get a "---Type <return> to continue, or q <return> to quit---"
  # prompt on start-up when GDB prints its version number and configuration options. Switch "--quiet" tries to minimize the problem.
  add_gdb_arg "--quiet"

  # GDB's constant confirmation prompts get on my nerves.
  add_gdb_cmd "set confirm off"

  add_gdb_cmd "set pagination off"

  # Command "focus cmd" automatically turns TUI on.
  if $ENABLE_TUI; then
    add_gdb_cmd "focus cmd"
  fi

  add_gdb_cmd "set print pretty on"

fi


# Prevent this kind of warning:
#   Reading C:/windows/system32/ntdll.dll from remote target...
#   Warning: File transfers from remote targets can be slow. Use "set sysroot" to access files locally instead.
# Use GDB command "info sharedlibrary" to check whether all DLLs and their debug symbols were loaded correctly.
add_gdb_cmd "set sysroot ${WINEPREFIX:-$HOME/.wine}/drive_c"


# Quoting of the filename does not seem necessary for the "set remote exec-file" command,
# even if the filename contains spaces. The GDB manual states that most commands do not support
# quoting anyway.
#
# I guess GDB or gdbserver is aware of Wine and is automatically translating
# the Unix-style path into a Windows-style path. Otherwise, we would need to translate
# the path ourselves with 'winepath'.
if $SHOULD_START_GDBSERVER_IN_MULTI_MODE; then
  add_gdb_cmd "set remote exec-file $WINDOWS_EXE_FILE_PATH_ABS"
fi

# Quoting the filename is necessary for the 'file' command, in case the path has spaces.
# I am not sure however whether the quoting rules in Bash are the same as in GDB,
# or at least compatible enough. It does work for paths which contain spaces.
printf -v TMP "%q" "$WINDOWS_EXE_FILE_PATH_ABS"
add_gdb_cmd "file $TMP"

# Setting 'remotetimeout' defaults to 2 seconds. The lower this value is, the faster
# the connection should be established when gdbserver is ready. However, this setting
# does not admit 0 or a fractional number of seconds, at least with GDB version 10.2,
# so the minimum is 1 second. I am not sure that this setting really applies if the host
# refuses the connection straight away. I think that GDB retries in less than 1 second.
add_gdb_cmd "set remotetimeout 1"

# Other connection-related GDB settings:
#   set tcp auto-retry on  - default is on.
#   set tcp connect-timeout unlimited/number_of_seconds - default is 15 seconds.

add_gdb_cmd "target extended-remote $GDBSERVER_HOST:$GDBSERVER_TCP_PORT"


if (( ${#BREAKPOINTS[*]} > 0 )); then
  for BP in "${BREAKPOINTS[@]}"; do
    add_gdb_cmd "break $BP"
  done
fi

if $SHOULD_START_GDBSERVER_IN_MULTI_MODE; then
  if $DEBUG_FROM_THE_START_SPECIFIED; then
    # Alternative which may stop earlier than 'start': starti
    add_gdb_cmd "start${CMD_LINE_ARGS}"
  else
    add_gdb_cmd "run${CMD_LINE_ARGS}"
  fi
else
  if ! $DEBUG_FROM_THE_START_SPECIFIED; then
    add_gdb_cmd "cont"
  fi
fi


if [[ $DEBUGGER_TYPE = "ddd" ]]; then

  echo
  echo "Starting DDD with command:"
  echo "$GDB_CMD"
  echo

  eval "$GDB_CMD"

else

  NEW_CONSOLE_CMD=""

  printf -v TMP "%q" "$RUN_IN_NEW_CONSOLE_TOOL"

  NEW_CONSOLE_CMD+="$TMP"

  NEW_CONSOLE_CMD+=" --console-discard-stderr"
  # Alternative icons could be: utilities-system-monitor, applications-development, application-x-executable.
  NEW_CONSOLE_CMD+=" --console-icon=applications-engineering"
  NEW_CONSOLE_CMD+=" --console-title=\"Wine GDB\""
  NEW_CONSOLE_CMD+=" --"
  NEW_CONSOLE_CMD+=" $(printf "%q" "$GDB_CMD")"

  echo
  echo "The GDB command is:"
  echo "$GDB_CMD"
  echo

  echo "Starting GDB in a new console with command:"
  echo "$NEW_CONSOLE_CMD"
  echo

  eval "$NEW_CONSOLE_CMD"

fi


# When GDB exits, the gdbserver may still be running. Whether it will remain
# depends on factors like the target architecture, or whether the user
# has issued GDB command "monitor exit". The gdbserver may actually be
# shutting down now, so it is easy to hit a race condition here.
# We should wait on the gdbserver job, or we risk leaving it behind unnoticed.

# If the job has already terminated, kill will print an error and fail (exit code != 0).
# Ignore this eventual failure.
set +o errexit
kill -SIGTERM "$GDBSERVER_JOB_SPEC" 2>/dev/null
set -o errexit

echo "Waiting for the gdbserver child process to terminate..."

# If gdbserver was still running and we terminated it with a signal,
# its exit code will not be zero.
set +o errexit
wait "$GDBSERVER_JOB_SPEC" 2>/dev/null
set -o errexit


echo "Debug session terminated."

exit $EXIT_CODE_SUCCESS
