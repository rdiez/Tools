#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


# Some desktops, like KDE, provide notifications that stay until you click them away. Then
# you may want to disable the pop-up message window notification.
# You should not disable this under Microsoft Windows, because taskbar notifications are not implemented yet on Windows.

declare -r ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION_ENV_VAR_NAME="BACKGROUND_SH_ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION"

declare -r ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION="${!ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION_ENV_VAR_NAME:-true}"


# Here you configure where the log files should be stored. You would normally choose one of the following options:
#
# 1) Create a file called "BackgroundCommand.log" in the current directory.
#
#    LOG_FILES_DIR=""  # If empty, it is equivalent to LOG_FILES_DIR="$PWD" .
#    FIXED_LOG_FILENAME="BackgroundCommand.log"  # If not empty: Please enter here just a filename without dir paths, see LOG_FILES_DIR above. LOG_FILENAME_PREFIX is then ignored.
#    ENABLE_LOG_FILE_ROTATION=false
#
# 2) Use a fixed directory for the log files, and rotate them in order to prevent ever-growing disk space consumption.
#
#    LOG_FILES_DIR="$HOME/.background.sh-log-files"  # If empty, it is equivalent to LOG_FILES_DIR="$PWD" .
#    FIXED_LOG_FILENAME=""  # If not empty: Please enter here just a filename without dir paths, see LOG_FILES_DIR above. LOG_FILENAME_PREFIX is then ignored.
#    LOG_FILENAME_PREFIX="BackgroundCommand-"  # This prefix is also used to find the files to delete during log file rotation.
#    ENABLE_LOG_FILE_ROTATION=true
#
#    Log rotation is performed by file count alone, and file size is not taken into account. This is a weakness in this script,
#    as a small number of huge log files can still fill-up the whole disk.
#

LOG_FILES_DIR="$HOME/.background.sh-log-files"  # If empty, it is equivalent to LOG_FILES_DIR="$PWD" .

declare -r NO_LOG_FILE="/dev/null"

FIXED_LOG_FILENAME=""  # If not empty: Please enter here just a filename without dir paths, see LOG_FILES_DIR above. LOG_FILENAME_PREFIX is then ignored.

LOG_FILENAME_PREFIX="BackgroundCommand-"  # This prefix is also used to find the files to delete during log file rotation.

ENABLE_LOG_FILE_ROTATION=true
MAX_LOG_FILE_COUNT=100  # Must be at least 1. However, a much higher value is recommended, because .lock files from other
                        # concurrent background.sh processes, and also orphaned .lock files left behind,
                        # are counted as normal .log files too for log rotation purposes.


# You can set the method this tool uses to run processes with a lower priority with environment variable BACKGROUND_SH_LOW_PRIORITY_METHOD:
#
# - Method "nice" uses the 'nice' tool to lower the process' priority.
#
#   This is normally the best choice, as it is a POSIX standard. Under Linux, it has
#   an impact on both CPU and disk priority. See variable NICE_TARGET_PRIORITY below.
#
# - Method "ionice" uses command "ionice --class x --classdata y".
#
#   This method is specific to Linux and affects disk I/O priority only.
#   You may want to switch to this method if you are running long background calculations
#   (like BOINC with SETI@home) and you are using the "ondemand" CPU scaling governor
#   with setting "ignore_nice_load" enabled in order to keep your laptop from
#   heating up and its fan from getting loud. Otherwise, any process started with
#   the 'nice' method will run more slowly than it probably should, as the CPU will
#   not run at its maximum frequency.
#   See variables IONICE_xxx below for the exact values used.
#
# - Method "ionice+chrt" combines "ionice" as described above with "chrt", which
#   sets the CPU scheduling policy. See variable CHRT_PRIORITY below.
#
# - Method "systemd-run" uses 'systemd-run --nice=xx'.
#
# - Method "none" does not modify the child process' priority.

declare -r LOW_PRIORITY_METHOD_DEFAULT="nice"

declare -r LOW_PRIORITY_METHOD_ENV_VAR_NAME="BACKGROUND_SH_LOW_PRIORITY_METHOD"
declare -r LOW_PRIORITY_METHOD="${!LOW_PRIORITY_METHOD_ENV_VAR_NAME:-$LOW_PRIORITY_METHOD_DEFAULT}"


# Command 'nice' can only decrease a process' priority. The trouble is, if you nest
# 'nice -n xx' commands, you may land at the absolute minimum value, which is
# probably not what you want, as your processes would then be sharing CPU time with
# other non-important system background processes, or with really low-priority tasks
# like your BOINC / SETI@home project.
# In order to prevent surprises, this script sets an absolute value as the target
# priority (instead of a delta). Note that other tools like 'ionice' use absolute
# priority values by default.
declare -i NICE_TARGET_PRIORITY=15

# Class 2 means "best-effort" and is equivalent to the default ionice priority.
declare -i IONICE_CLASS=2
# Priority 7 is the lowest priority in the "best-effort" class.
declare -i IONICE_PRIORITY=7

declare -r CHRT_SCHEDULING_POLICY="--batch"
declare -r CHRT_PRIORITY="0"  # Must be 0 if you are using scheduling policy 'batch'.


#  ----- You probably do not need to modify anything beyond this point -----

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r VERSION_NUMBER="2.50"
declare -r SCRIPT_NAME="background.sh"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2019 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool runs the given command with a low priority, copies its output to a log file, and displays a visual notification when finished."
  echo
  echo "The visual notification consists of a transient desktop taskbar indication (if command 'notify-send' is installed) and a permanent message box (a window that pops up). If you are sitting in front of the screen, the taskbar notification should catch your attention, even if the message box remains hidden beneath other windows. Should you miss the notification, the message box remains open until manually closed. If your desktop environment makes it hard to miss notifications, you can disable the message box, see ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION in this script's source code, or see environment variable $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION_ENV_VAR_NAME below."
  echo
  echo "This tool is useful in the following scenario:"
  echo "- You need to run a long process, such as copying a large number of files or recompiling a big software project."
  echo "- You want to carry on using the computer for other tasks. That long process should run with a low CPU and/or disk priority in the background. By default, the process' priority is reduced to $NICE_TARGET_PRIORITY with 'nice', but you can switch to 'ionice', 'chrt' or 'systemd-run', see variable LOW_PRIORITY_METHOD in this script's source code for more information."
  echo "- You want to leave the command's console (or Emacs frame) open, in case you want to check its progress in the meantime."
  echo "- You might inadvertently close the console window at the end, so you need a persistent log file with all the console output for future reference. You can choose where the log files land and whether they rotate, see option --log-file and variable LOG_FILES_DIR in this script's source code."
  echo "- [disabled] The log file should optimise away the carriage return trick often used to update a progress indicator in place on the current console line."
  echo "- You may not notice when the process has completed, so you would like a visible notification in your desktop environment (like KDE or Xfce)."
  echo "- You would like to know immediately if the process succeeded or failed (an exit code of zero would mean success)."
  echo "- You want to know how long the process took, in order to have an idea of how long it may take the next time around."
  echo "- You want the PID of your command's parent process automatically displayed at the beginning, in order to temporarily suspend all related child processes at once with pkill, should you need the full I/O performance at this moment for something else."
  echo "- You want all that functionality conveniently packaged in a script that takes care of all the details."
  echo "- All that should work under Cygwin on Windows too."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME <options...> <--> command <command arguments...>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo " --notify-only-on-error  Some scripts display their own notifications,"
  echo "                         so only notify if something went wrong."
  echo " --no-desktop            Do not issue any desktop notifications at the end."
  echo " --email                 Sends a notification e-mail when the command has finished."
  echo "                         See below for e-mail configuration information."
  echo " --no-console-output     Places all command output only in the log file. Depending on"
  echo "                         where the console is, you can save CPU and/or network bandwidth."
  echo " --log-file=filename     Instead of rotating log files, use a fixed filename."
  echo "                         Specify $NO_LOG_FILE for no log file."
  echo " --filter-log            Filters the command's output with FilterTerminalOutputForLogFile.pl"
  echo "                         before placing it in the log file."
  echo " --compress-log          Compresses the log file. Log files tend to be very repetitive"
  echo "                         and compress very well. Note that Cygwin has issues with FIFOs"
  echo "                         as of feb 2019, so this option will probably hang on Cygwin."
  echo " --memory-limit=x        Passed as --property=MemoryLimit=x to systemd-run."
  echo "                         Use suffix K, M, G or T for units KiB, MiB, GiB and TiB."
  echo "                         Only available when using the 'systemd-run' LOW_PRIORITY_METHOD."
  echo "                         See further below for more information."
  echo " --no-prio               Do not change the child process priority."
  echo
  echo "Environment variables:"
  echo "  $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION_ENV_VAR_NAME=true/false"
  echo
  echo "Usage examples:"
  echo "  ./$SCRIPT_NAME -- echo \"Long process runs here...\""
  echo "  ./$SCRIPT_NAME -- sh -c \"exit 5\""
  echo
  echo "Usage scenario for remote servers:"
  echo
  echo -n "Say that you are running a long process on a server over an SSH network connection. If the connection is lost, "
  echo -n "the process terminates, unless you are using something like 'screen' or 'tmux', but then you will probably "
  echo -n "not have a desktop session for the visual notification. An email notification is probably better. "
  echo -n "In such a remote session, you do not expect any interaction with the long process, so trying to read from "
  echo -n "stdin should fail. You will probably want a fixed log filename too. "
  echo -n "In this scenario, the following options are probably more suitable:"
  echo
  echo
  echo "  ./$SCRIPT_NAME --log-file=output.log  --no-desktop  --email -- your_command  </dev/null"
  echo
  echo "Notification e-mails are sent with S-nail. You will need a .mailrc configuration file"
  echo "in your home directory. There is a .mailrc example file next to this script."
  echo
  echo "Caveat: If you start several instances of this script and you are using a fixed log filename (without log file rotation), you should do it from different directories. This script attempts to detect such a situation by creating a temporary lock file named after the log file and obtaining an advisory lock on it with flock (which depending on the underlying filesystem may have no effect)."
  echo
  echo "About the --memory-limit option:"
  echo "  The Linux filesystem cache is braindead (as of Kernel 5.0.0 in september 2019). Say you have 2 GiB of RAM and "
  echo "  you copy 2 GiB's worth of data from one disk directory to another. That will effectively flush the Linux"
  echo "  filesystem cache, and you don't even have to be root. Anything you want to do afterwards will have to reload"
  echo "  any other files needed from disk, which means that the system will always respond slowly after copying large files."
  echo
  echo "  In order to reduce the cache impact on other processes, I have looked for ways to limit cache usage."
  echo "  The only way I found is to set a memory limit in a cgroup, but unfortunately that affects all memory usage"
  echo "  within the cgroup, and not just the file cache. The only tool I found to painlessly create a temporary"
  echo "  cgroup is 'systemd-run', and even this way is not without rough edges."
  echo
  echo "  If your command hits the memory limit, the OOM killer will terminate the whole group, and the error message"
  echo "  will simply be 'Killed'. Unfortunately, the only alternative OOM behaviour is to pause processes until"
  echo "  more memory is available, which does not really work well in practice."
  echo
  echo "Exit status: Same as the command executed. Note that this script assumes that 0 means success."
  echo
  echo "Still to do:"
  echo "- This script could take optional parameters with the 'nice' level and the visual notification method."
  echo "- Linux 'cgroups', if available, would provide a better CPU and/or disk prioritisation."
  echo "- Under Cygwin on Windows there is not taskbar notification yet, only the message box is displayed. I could not find an easy way to create a taskbar notification with a .vbs or similar script."
  echo "- Log file rotation could be smarter: by global size, by date or combination of both."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license ()
{
cat - <<EOF

Copyright (c) 2011-2019 R. Diez

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


rotate_log_files ()
{
  local FIND_DIR="$1"
  local LOG_FILENAME_PREFIX="$2"

  # Sometimes .lock files are left behind due to power failures or some other catastrophic events.
  # This routine will count them as normal .log files and delete them accordingly.
  # Also, if other background.sh processes are running concurrently, their in-use .lock files will also
  # be counted as normal .log files.
  #
  # This means that MAX_LOG_FILE_COUNT will not be entirely accurate, as the number of normal .log files
  # left behind depends on how many .lock files are currently in use and how many were left behind as orphans.
  # But it is probably not worth fixing this issue.
  #
  # We should use -print0, but it is hard to process null-separated strings with Bash and the GNU tools.
  # Because we are in control of the filenames, there should not be much room for trouble.

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command invoked.
  local FILE_LIST
  local FILE_COUNT

  FILE_LIST="$(find "$FIND_DIR" -maxdepth 1 \! -name $'*\n*'  \( -type f  -o  -type p \)  -name "$LOG_FILENAME_PREFIX*" | sort)"
  FILE_COUNT="$(echo "$FILE_LIST" | wc --lines)"

  if false; then
    printf "FILE_LIST:\\n%s\\n" "$FILE_LIST"
    echo "FILE_COUNT: $FILE_COUNT"
  fi

  if (( FILE_COUNT + 1 > MAX_LOG_FILE_COUNT )); then

    FILE_COUNT_TO_DELETE=$(( FILE_COUNT + 1 - MAX_LOG_FILE_COUNT ))

    # We normally delete just 1 file every time, so there should not be a long pause.
    # Therefore, we do not really need to print a "deleting..." message before rotating the log files.
    if false; then
      echo "Deleting $FILE_COUNT_TO_DELETE old $SCRIPT_NAME log file(s)..."
    fi


    # Do not use the 'head' command here in order to select the first files from the list,
    # as it has the nasty habit of closing stdin early when it reads enough lines.
    # If the amount of data is bigger than the read buffer in 'head',
    # that early closing will kill this script with a broken pipe signal.
    # The exit code is then 128 + 13 (SIGPIPE) = 141.
    # I hope that 'readarray' and '<<<' do not have the same problem.
    # I tested it under Linux with a huge string, but the implementation may be
    # platform dependent.

    local -a FILES_TO_DELETE
    readarray -n "$FILE_COUNT_TO_DELETE"  -t  FILES_TO_DELETE  <<<"$FILE_LIST"

    if false; then
      echo "Files to delete:"
      printf '%s\n'  "${FILES_TO_DELETE[@]}"
    fi


    # xargs has issues not only with newlines, but with the space, tab, single quote, double quote and backslash characters
    # as well, so use the null-character as separator.

    printf '%s\n'  "${FILES_TO_DELETE[@]}" | tr '\n' '\0' | xargs -0 rm --
  fi
}


display_desktop_notification ()
{
  local TITLE="$1"
  local HAS_FAILED="$2"

  if is_tool_installed "$TOOL_NOTIFY_SEND"; then

    if $HAS_FAILED; then
      "$TOOL_NOTIFY_SEND" --icon=dialog-error       -- "$TITLE"
    else
      "$TOOL_NOTIFY_SEND" --icon=dialog-information -- "$TITLE"
    fi

  else
    echo "Note: The '$TOOL_NOTIFY_SEND' tool is not installed, therefore no desktop pop-up notification will be issued. You may have to install this tool with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"libnotify-bin\"."
  fi
}


display_notification ()
{
  local TITLE="$1"
  local TEXT="$2"
  local LOG_FILENAME="$3"
  local HAS_FAILED="$4"

  if $NO_DESKTOP; then
    return
  fi

  if [[ $OSTYPE = "cygwin" ]]
  then

    # Alternatively, xmessage is available on Cygwin.

    TMP_VBS_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_NAME.XXXXXXXXXX.vbs")"
    cat >"$TMP_VBS_FILENAME" <<EOF
Option Explicit
Dim args
Set args = WScript.Arguments
MsgBox args(1) & vbCrLf & vbCrLf & "Log file: " & args(2), vbOKOnly, args(0)
WScript.Quit(0)
EOF

    echo "Waiting for the user to close the notification message box window..."
    # Here we cross the line between the Unix and the Windows world. The command-line argument escaping
    # is a little iffy at this point, but the title and the text are not user-defined, but hard-coded
    # in this script. Therefore, this simplified string argument passing should be OK.
    VB_SCRIPT_ARGUMENTS="\"$TITLE\" \"$TEXT\" \"$LOG_FILENAME\""
    cygstart --wait "$TMP_VBS_FILENAME" "$VB_SCRIPT_ARGUMENTS"
    rm "$TMP_VBS_FILENAME"

  else

    display_desktop_notification "$TITLE" "$HAS_FAILED"

    if $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION; then
      echo "Waiting for the user to close the notification message box window..."
      # Remember that, if the user closes the window without pressing the OK button, the exit status is non-zero.
      # That is the reason why there is a "|| true" at the end.
      echo -n -e "$TEXT\\n\\nLog file: $LOG_FILENAME" | "$UNIX_MSG_TOOL" -title "$TITLE" -file - || true
    fi
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
    notify-only-on-error)
        NOTIFY_ONLY_ON_ERROR=true
        ;;
    no-console-output)
        NO_CONSOLE_OUTPUT=true
        ;;
    no-desktop)
        NO_DESKTOP=true
        ;;
    email)
        NOTIFY_PER_EMAIL=true
        ;;
    log-file)
      if [[ $OPTARG = "" ]]; then
        abort "Option --log-file has an empty value.";
      fi
      ENABLE_LOG_FILE_ROTATION=false
      FIXED_LOG_FILENAME="$OPTARG"
      LOG_FILES_DIR=""
      ;;
    filter-log)
       FILTER_LOG=true
       ;;
    compress-log)
      COMPRESS_LOG=true
      ;;

    memory-limit)
      if [[ $OPTARG = "" ]]; then
        abort "The --memory-limit option has an empty value.";
      fi
      MEMORY_LIMIT="$OPTARG"
      ;;

    no-prio)
       NO_PRIO=true
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

if (( EUID == 0 )); then
  abort "This script is designed for interactive usage: it issues desktop notifications"\
        "and creates a log file. Running it as root is normally a bad idea. You can of course"\
        "run commands with it that use sudo etc. in order to run child processes as root."
fi

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [notify-only-on-error]=0 )
USER_LONG_OPTIONS_SPEC+=( [no-console-output]=0 )
USER_LONG_OPTIONS_SPEC+=( [email]=0 )
USER_LONG_OPTIONS_SPEC+=( [no-desktop]=0 )
USER_LONG_OPTIONS_SPEC+=( [filter-log]=0 )
USER_LONG_OPTIONS_SPEC+=( [log-file]=1 )
USER_LONG_OPTIONS_SPEC+=( [compress-log]=0 )
USER_LONG_OPTIONS_SPEC+=( [memory-limit]=1 )
USER_LONG_OPTIONS_SPEC+=( [no-prio]=0 )

NOTIFY_ONLY_ON_ERROR=false
NO_CONSOLE_OUTPUT=false
NO_DESKTOP=false
NOTIFY_PER_EMAIL=false
FILTER_LOG=false
COMPRESS_LOG=false
MEMORY_LIMIT=""
NO_PRIO=false

parse_command_line_arguments "$@"


if (( ${#ARGS[@]} < 1 )); then
  abort "No command specified. Run this tool with the --help option for usage information."
fi


case "$ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION" in
  true)  ;;
  false) ;;
  *) abort "Environment variable $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION_ENV_VAR_NAME has an invalid value of \"$ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION\"." ;;
esac


if [[ $MEMORY_LIMIT != "" && $LOW_PRIORITY_METHOD != "systemd-run" ]]; then
  abort "Option '--memory-limit' is only available with LOW_PRIORITY_METHOD 'systemd-run'."
fi


# Notification procedure:
# - Under Unix, use 'notify-send' if available to display a desktop notification, which normally
#   appears at the bottom right corner over the taskbar. In addition to that optional short-lived
#   notification, open a message box with 'gxmessage' that the user must manually close. That is
#   in case the user was not sitting in front of the screen when the temporary notification popped up.
# - Under Cygwin, use a native Windows script instead for notification purposes.
#   Desktop pop-up notifications are not implemented yet, you only get the message box.

declare -r TOOL_NOTIFY_SEND="notify-send"

declare -r UNIX_MSG_TOOL="gxmessage"

if ! $NO_DESKTOP; then
  if ! [[ $OSTYPE = "cygwin" ]]; then
    if $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION; then
      verify_tool_is_installed "$UNIX_MSG_TOOL" "gxmessage"
    fi
  fi
fi

declare -r FILTER_LOG_TOOL="FilterTerminalOutputForLogFile.pl"

if $FILTER_LOG; then
  command -v "$FILTER_LOG_TOOL" >/dev/null 2>&1  ||  abort "Script '$FILTER_LOG_TOOL' not found. Make sure it is on the PATH."
fi


declare -r S_NAIL_TOOL="s-nail"

if $NOTIFY_PER_EMAIL; then
  verify_tool_is_installed "$S_NAIL_TOOL" "s-nail"
fi


declare -r COMPRESS_TOOL="7z"

if $COMPRESS_LOG; then
  verify_tool_is_installed "$COMPRESS_TOOL" "p7zip-full"
fi


if ! $NO_PRIO; then
  case "$LOW_PRIORITY_METHOD" in
    # In the case of 'systemd-run', it might actually be possible to set a higher 'nice' priority. More research is needed.
    nice|systemd-run)
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

      ;;
    *) :  # Nothing to do here.
  esac
fi

# Rotating the log files can take some time. Print some message so that the user knows that something
# is going on.
printf  -v USER_CMD  " %q"  "${ARGS[@]}"
USER_CMD="${USER_CMD:1}"  # Remove the leading space.
echo "Running command with low priority: $USER_CMD"

if [[ $LOG_FILES_DIR == "" ]]; then
  ABS_LOG_FILES_DIR="$(readlink --canonicalize --verbose -- "$PWD")"
else
  ABS_LOG_FILES_DIR="$(readlink --canonicalize --verbose -- "$LOG_FILES_DIR")"
  mkdir --parents -- "$ABS_LOG_FILES_DIR"
fi


declare -r COMPRESSED_LOG_FILENAME_SUFFIX=".7z"

if $COMPRESS_LOG; then
  declare -r LOG_FILENAME_SUFFIX="$COMPRESSED_LOG_FILENAME_SUFFIX"
else
  declare -r LOG_FILENAME_SUFFIX=""
fi


# Deleting old log files may take some time. Do it after printing the first message. Otherwise,
# the user may stare a long time at an empty terminal.

if $ENABLE_LOG_FILE_ROTATION; then

  if [[ $FIXED_LOG_FILENAME != "" ]]; then
    abort "Cannot rotate log files if the log filename is fixed."
  fi

  if [[ $LOG_FILENAME_PREFIX == "" ]]; then
    abort "Cannot rotate log files if the log filename prefix is empty."
  fi

  rotate_log_files "$ABS_LOG_FILES_DIR" "$LOG_FILENAME_PREFIX"
fi


if [[ $FIXED_LOG_FILENAME == "" ]]; then

  if [[ $LOG_FILENAME_PREFIX == "" ]]; then
    abort "The log filename prefix cannot be empty."
  fi

  # Files are rotated by name, so the timestamp must be at the end, and its format should lend itself to be sorted as a standard string.
  # Note that Microsoft Windows does not allow colons (':') in filenames.
  printf -v LOG_FILENAME_MKTEMP_FMT "$LOG_FILENAME_PREFIX%(%F-%H-%M-%S)T-XXXXXXXXXX.log$LOG_FILENAME_SUFFIX"

  LOG_FILENAME="$(mktemp --tmpdir="$ABS_LOG_FILES_DIR" "$LOG_FILENAME_MKTEMP_FMT")"

elif [[ $FIXED_LOG_FILENAME == "$NO_LOG_FILE" ]]; then

  LOG_FILENAME="$NO_LOG_FILE"

  if $COMPRESS_LOG; then
    abort "Cannot compress a $NO_LOG_FILE log file."
  fi

  if $FILTER_LOG; then
    abort "Cannot filter a $NO_LOG_FILE log file."
  fi

else

  if [[ $LOG_FILES_DIR == "" ]]; then
    LOG_FILENAME="$FIXED_LOG_FILENAME"
  else
    LOG_FILENAME="$ABS_LOG_FILES_DIR/$FIXED_LOG_FILENAME"
  fi

  LOG_FILENAME+="$LOG_FILENAME_SUFFIX"

  # Create the log file, or truncate it if it already exists.
  echo -n "" >"$LOG_FILENAME"

fi

declare -r LOCK_FILENAME="$LOG_FILENAME.lock"
declare -r COMPRESSION_FIFO_FILENAME="$LOG_FILENAME.comprfifo"

ABS_LOG_FILENAME="$(readlink --canonicalize --verbose -- "$LOG_FILENAME")"
ABS_LOCK_FILENAME="$(readlink --canonicalize --verbose -- "$LOCK_FILENAME")"
ABS_COMPRESSION_FIFO_FILENAME="$(readlink --canonicalize --verbose -- "$COMPRESSION_FIFO_FILENAME")"

if false; then
  echo "ABS_LOG_FILENAME: $LOG_FILENAME"
  echo "ABS_LOCK_FILENAME: $LOCK_FILENAME"
  echo "ABS_COMPRESSION_FIFO_FILENAME: $ABS_COMPRESSION_FIFO_FILENAME"
fi


if [[ $FIXED_LOG_FILENAME != "$NO_LOG_FILE" ]]; then

  create_lock_file
  lock_lock_file

fi

if $COMPRESS_LOG; then

  # Create the child process that will do the compression on the fly.
  # Create a FIFO in order to forward the data between everything else
  # and the child compression process.


  # I could not make Bash' "coproc" to work, so I am using a named FIFO instead.
  # I also tried with the usual trick of creating a FIFO, unlinking it
  # and keeping a file descriptor open, but I had all sort of weird problems
  # under Linux, and different issues under Cygwin.

  # 600 = only the owner can read and write to the FIFO.
  declare -r COMPRESS_FIFO_FILE_MODE="600"

  # Delete the FIFO if it already exists. It may have left behind
  # if the previous run failed to delete the FIFO before aborting.

  if [ -p "$ABS_COMPRESSION_FIFO_FILENAME" ]; then
    rm -- "$ABS_COMPRESSION_FIFO_FILENAME"
  fi

  mkfifo --mode="$COMPRESS_FIFO_FILE_MODE" -- "$ABS_COMPRESSION_FIFO_FILENAME"


  # The choice of compression program and algorithm is not an easy one to make.
  # Your mileage will vary.

  declare -r COMPRESSION_METHOD="lzma2"

  case "$COMPRESSION_METHOD" in

    zip)
       # 7z with the zip algorihtm seems to perform better than the similar "gzip --fast" method.
       COMPRESSION_ARGS="-m0=Deflate -mx1";;

    lzma2)
       # This method provides a good balance.
       # Using multithreaded compression actually slightly reduces the compression ratio.
       # Multithreaded compression only works with the lzma2 algorithm, at least
       # with 7z version 9.20.
       COMPRESSION_ARGS="-m0=lzma2  -mx1  -mmt=on";;

    *)  # We should actually never land here, because parse_command_line_arguments() already checks if an option is known.
        abort "Unknown compression method \"$COMPRESSION_METHOD\".";;
  esac


  # 7z's 'add' command does not like an existing file, even if it is empty.
  rm "$ABS_LOG_FILENAME"


  # The 'exec' removes the unnecesary interposed Bash instance (the subshell).
  #
  # 7z has not "quiet" option, so we need to pipe its stdout to /dev/null, or
  # its progress output will get mixed up with the user's command output.

  printf -v COMPRESS_CMD \
         "exec  %q  a  -si  -t7z  %s -- %q  >/dev/null" \
         "$COMPRESS_TOOL" \
         "$COMPRESSION_ARGS" \
         "$ABS_LOG_FILENAME"

  eval "$COMPRESS_CMD"  <"$ABS_COMPRESSION_FIFO_FILENAME"  &

  COMPRESS_PID="$(jobs -p %+)"

  # Attach a file descriptor to the FIFO. Open it after creating the compression
  # process, so that the child process does not inherit the file descriptor.
  # Keep the file descriptor open while other operations open and close the FIFO.
  # This file descriptor will be closed last.
  exec {COMPRESS_FIFO_FD}>"$ABS_COMPRESSION_FIFO_FILENAME"

  declare -r ABS_LOG_FILENAME_FOR_WRITING="$ABS_COMPRESSION_FIFO_FILENAME"

else

  declare -r ABS_LOG_FILENAME_FOR_WRITING="$ABS_LOG_FILENAME"

fi


# POSSIBLE IMPROVEMENT: At the moment, log filtering and compression are not done with the same lower priority as the user command.

WRAPPER_CMD=""

if $NO_PRIO && [[ $LOW_PRIORITY_METHOD != "systemd-run" ]]; then

  WRAPPER_CMD="$USER_CMD"

else

  case "$LOW_PRIORITY_METHOD" in
    none)        WRAPPER_CMD="$USER_CMD";;
    nice)        WRAPPER_CMD="nice -n $NICE_DELTA -- $USER_CMD";;
    ionice)      WRAPPER_CMD="ionice --class $IONICE_CLASS --classdata $IONICE_PRIORITY -- $USER_CMD";;
    ionice+chrt) # Unfortunately, chrt does not have a '--' switch in order to clearly delimit its options from the command to run.
                 printf -v WRAPPER_CMD  \
                        "ionice --class $IONICE_CLASS --classdata $IONICE_PRIORITY -- chrt %q %q %s" \
                        "$CHRT_SCHEDULING_POLICY" \
                        "$CHRT_PRIORITY" \
                        "$USER_CMD";;

    # As far as I can tell, there are 2 ways to use systemd-run:
    #
    #   Alternative 1) systemd-run --user --wait --pipe -- cmd...
    #     This way is not ideal, because the environment is not inherited.
    #
    #   Alternative 2) systemd-run --scope -- cmd...
    #     If you do not have the org.freedesktop.systemd1.manage-units privilege, it will prompt you for credentials,
    #     which is cumbersome.
    #
    #     I also wanted to use option '--user' in this alternative, but under Ubuntu 18.04 you get the following error:
    #       Failed to add PIDs to scope's control group: Permission denied
    #     According to some voices on the Internet, this is a shorcoming that might be fixed in the future.
    #
    #
    # About option '--quiet':
    #   Tool 'systemd-run' without '--scope' and with '--wait' (alternative 1 above) is actually too verbose for my liking:
    #       Running as unit: run-u107.service
    #       < ... normal command output here ... >
    #       Finished with result: success
    #       Main processes terminated with: code=exited/status=0
    #       Service runtime: 5ms
    #   We could suppress all of that with option '--quiet', but the user may need the unit name after all,
    #   for example in order to pause or kill it.
    #   With option '--scope' (alternative 2 above) the output is shorter:
    #       Running scope as unit: run-u281.scope
    #   I also noticed that option '--quiet' suppresses any error message if the unit/scope itself fails to start,
    #   so it may not be a good idea to use it.

    systemd-run)
       declare -r SYSTEMD_RUN_TOOL="systemd-run"
       verify_tool_is_installed "$SYSTEMD_RUN_TOOL" ""

       CMD_OPTIONS=""

       if [[ $MEMORY_LIMIT != "" ]]; then
         printf -v MEM_LIMIT_ARG -- "--property=MemoryLimit=%q"  "$MEMORY_LIMIT"
         CMD_OPTIONS+=" $MEM_LIMIT_ARG "
       fi

       if ! $NO_PRIO; then
         printf -v PRIO_ARG -- "--nice=%q"  "$NICE_TARGET_PRIORITY"
         CMD_OPTIONS+=" $PRIO_ARG "
       fi

       printf -v WRAPPER_CMD  "%q  --scope %s -- %s"  "$SYSTEMD_RUN_TOOL"  "$CMD_OPTIONS"  "$USER_CMD";;

    *) abort "Unknown LOW_PRIORITY_METHOD \"$LOW_PRIORITY_METHOD\".";;
  esac

fi

if $NO_CONSOLE_OUTPUT; then
  # If there is no console output, it probably makes no sense to allow console input.
  declare -r DROP_STDIN=true
else
  # If you do not expect any interaction with the long process, trying to read from stdin should fail,
  # instead of forever waiting for a user who is not paying attention. In this case,
  # you may want to turn this on:
  declare -r DROP_STDIN=false
fi

if $DROP_STDIN; then
  declare -r REDIRECT_STDIN="</dev/null"
else
  declare -r REDIRECT_STDIN=""
fi

# Duplicate the stdout file descriptor.
exec {STDOUT_COPY}>&1

# The first element of this array is actually never used.
declare -a PIPE_ELEM_NAMES=("user command")

printf -v PIPE_CMD  "eval %q %s"  "$WRAPPER_CMD"  "$REDIRECT_STDIN"

LOG_FILE_PROCESSOR=""
declare -a LOG_FILE_PROCESSOR_ELEM_NAMES=()

if $FILTER_LOG; then

  LOG_FILE_PROCESSOR_ELEM_NAMES+=( "$FILTER_LOG_TOOL" )

  printf -v TMP \
         "| %q -" \
         "$FILTER_LOG_TOOL"

  LOG_FILE_PROCESSOR+="$TMP"

  # Here we may have more pipelined commands in the future.

  printf -v TMP \
          " >>%q" \
          "$ABS_LOG_FILENAME_FOR_WRITING"

  LOG_FILE_PROCESSOR+="$TMP"

fi


if $NO_CONSOLE_OUTPUT; then

  if [ -z "$LOG_FILE_PROCESSOR" ]; then

    printf -v PIPE_CMD \
           "%s >>%q 2>&1" \
           "$PIPE_CMD" \
           "$ABS_LOG_FILENAME_FOR_WRITING"

  else

    PIPE_ELEM_NAMES+=( "${LOG_FILE_PROCESSOR_ELEM_NAMES[@]}" )

    printf -v PIPE_CMD \
           "%s 2>&1 %s" \
           "$PIPE_CMD" \
           "$LOG_FILE_PROCESSOR"
  fi

else

  if [ -z "$LOG_FILE_PROCESSOR" ]; then

    if [[ $FIXED_LOG_FILENAME == "$NO_LOG_FILE" ]]; then

      : # Do not modify PIPE_CMD here.

    else

      PIPE_ELEM_NAMES+=( "tee" )

      printf -v PIPE_CMD \
             "%s 2>&1 | tee --append -- %q" \
             "$PIPE_CMD" \
             "$ABS_LOG_FILENAME_FOR_WRITING"
    fi

  else

    # When using tee and applying a log file filter, this is the command we actually want:
    #
    #   some_eval_cmd | tee >( some_filter >>"$ABS_LOG_FILENAME_FOR_WRITING" )
    #
    # The trouble is, Bash versions 4.3, 4.4 (and probably later too) do not wait for the child process
    # in a process substitution to exit. This means that Bash does not wait for the 'col' command above
    # to terminate. As a result the last lines of the log file become garbled, as output from 'col'
    # and from this script are randomly interleaved.
    #
    # A simple trick to make Bash wait properly is to append "| cat" to the command. But that makes
    # all output go through 'cat', which unnecessarily burns CPU cycles.
    #
    # There are further redirection tricks that could work. But I figured that I could
    # just reverse the normal 'tee' usage, so that the filename is actually stdout
    # and its normal standard output gets piped to 'col' and redirected to the log file.
    #
    # This reversing only works if the system supports the /dev/fd method of naming open file descriptors,
    # but that is the case on Linux and Cygwin.

    PIPE_ELEM_NAMES+=( "tee" )
    PIPE_ELEM_NAMES+=( "${LOG_FILE_PROCESSOR_ELEM_NAMES[@]}" )

    printf -v PIPE_CMD \
           "%s 2>&1 | tee /dev/fd/$STDOUT_COPY %s" \
           "$PIPE_CMD" \
           "$LOG_FILE_PROCESSOR"
  fi

fi


# Copy the exit status array, or it will get lost when the next command executes.
# This needs to run inside the 'eval' command.
PIPE_CMD+=" ; declare -a -r CAPTURED_PIPESTATUS=( \"\${PIPESTATUS[@]}\" )"

declare -r PRINT_WRAPPER_CMD=false

if $PRINT_WRAPPER_CMD; then
  echo "Actual wrapper command: $PIPE_CMD"
fi

if [[ $LOW_PRIORITY_METHOD == "systemd-run" ]]; then
  # The user command does not end up as child process. Instead, there is some pkttyagent child process.
  # Sending a signal to that process does not affect the user command.
  # I tried to use systemd-run option '--pipe', but that is not compatible with '--scope'.
  SUSPEND_CMD=$'You can suspend all subprocesses with this command:\n  systemctl kill  --kill-who=all  --signal=STOP  <scope name>\n'
  SUSPEND_CMD+=$'You will find the scope name in the next log lines below.\n'
  SUSPEND_CMD+=$'Alternatively, list all scopes with command: systemctl list-units --type=scope\n'
else
  printf -v SUSPEND_CMD "The parent process ID is %s. You can suspend all subprocesses with this command:\\n  pkill --parent %s --signal STOP\\n"  "$BASHPID"  "$BASHPID"
fi

printf "%s" "$SUSPEND_CMD"

if [[ $FIXED_LOG_FILENAME != "$NO_LOG_FILE" ]]; then
  echo "The log file is: $ABS_LOG_FILENAME"
fi

echo


{
  echo "Running command: $USER_CMD"

  if $PRINT_WRAPPER_CMD; then
    echo "Actual wrapper command: $PIPE_CMD"
  fi

  # Write the suspend command hint to the log file too. If that hint has scrolled out of view
  # in the current console, and is no longer easy to find, the user will probably look
  # for it at the beginning of the log file.
  printf "%s" "$SUSPEND_CMD"

  echo
} >>"$ABS_LOG_FILENAME_FOR_WRITING"

read_uptime_as_integer
SYSTEM_UPTIME_BEGIN="$UPTIME"

set +o errexit
set +o pipefail

eval "$PIPE_CMD"

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

# Check any errors in the pipe elements after the user command.
# The reason is, if one of those fails, the user command will
# probably fail with a "broken pipe" error too.
# This is the same reason why we check for error right to left.

for (( i = EXPECTED_PIPE_ELEM_COUNT - 1; i != 0; i-- ))
do
  if [ "${CAPTURED_PIPESTATUS[$i]}" -ne 0 ]; then
   abort "The '${PIPE_ELEM_NAMES[$i]}' command in the pipe failed with exit status ${CAPTURED_PIPESTATUS[$i]}."
  fi
done


declare -r -i CMD_EXIT_CODE="${CAPTURED_PIPESTATUS[0]}"

declare -r LF=$'\n'

if (( CMD_EXIT_CODE == 0 )); then
  HAS_CMD_FAILED=false
  TITLE="Background command OK"
  MSG="The command finished successfully."
  EMAIL_TITLE="$SCRIPT_NAME command succeeded"
  EMAIL_BODY="$SCRIPT_NAME command succeeded:${LF}${LF}$USER_CMD"
else
  HAS_CMD_FAILED=true
  TITLE="Background command FAILED"
  MSG="The command failed with exit code $CMD_EXIT_CODE."
  EMAIL_TITLE="$SCRIPT_NAME command failed"
  EMAIL_BODY="$SCRIPT_NAME command failed:${LF}${LF}$USER_CMD"
fi

get_human_friendly_elapsed_time "$(( SYSTEM_UPTIME_END - SYSTEM_UPTIME_BEGIN ))"

{
  echo
  echo "Finished running command: $USER_CMD"
  echo "$MSG"
  echo "Elapsed time: $ELAPSED_TIME_STR"

  if $HAS_CMD_FAILED || ! $NOTIFY_ONLY_ON_ERROR; then

    if $NOTIFY_PER_EMAIL; then

      echo "Sending notification e-mail..."

      set +o errexit

      # Use options "-v -v" below to turn on detailed logging for troubleshooting purposes.
      # Beware that it will then print your password in clear text to the log file.

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

  fi

} 2>&1 </dev/null | tee --append -- "$ABS_LOG_FILENAME_FOR_WRITING"


if $COMPRESS_LOG; then

  # Close the FIFO file descriptor. This should be the last descriptor open
  # on the FIFO. Closing it should make the child process exit.
  exec {COMPRESS_FIFO_FD}>&-

  # If there are reliability issues again, you can turn on tracing here:
  declare -r TRACE_LOG_COMPRESSION_PROCESS_WAITING=false

  if $TRACE_LOG_COMPRESSION_PROCESS_WAITING; then
    echo "Waiting for the log compression process to finish..."
  fi

  set +o errexit
  wait "$COMPRESS_PID"
  WAIT_EXIT_CODE="$?"
  set -o errexit

  if $TRACE_LOG_COMPRESSION_PROCESS_WAITING; then
    echo "Finished waiting for the log compression process to finish."
  fi

  # It is actually rather late to check for errors in the compression process.
  # We should actually do it before checking any other pipeline errors from the user command,
  # because any failure in the compression process will make the others fail, or even hang.
  # However, checking for errors in a different order is hard to implement.

  if (( WAIT_EXIT_CODE != 0 )); then
    echo "ERROR: The log compression process failed with exit code $WAIT_EXIT_CODE."
  fi

  rm -- "$ABS_COMPRESSION_FIFO_FILENAME"

fi


if $HAS_CMD_FAILED || ! $NOTIFY_ONLY_ON_ERROR; then
  display_notification "$TITLE"  "$MSG"  "$ABS_LOG_FILENAME"  "$HAS_CMD_FAILED"
fi


if [[ $FIXED_LOG_FILENAME != "$NO_LOG_FILE" ]]; then

  # Close the lock file, which releases the lock we have on it.
  exec {LOCK_FILE_FD}>&-

  # Delete the lock file, which is actually an optional step, as this script will run fine
  # next time around if the file already exists.
  # The lock file survives if you kill the script with a signal like Ctrl+C, but that is a good thing,
  # because the presence of the lock file will probably remind the user that the background process
  # was abruptly interrupted.
  # There is the usual trick of deleting the file upon creation, in order to make sure that it is
  # always deleted, even if the process gets killed. However, it is not completely safe,
  # as the process could get killed right after creating the file but before deleting it.
  # Furthermore, it is confusing, for the file still exists but it is not visible. Finally, I am not sure
  # whether flock will work properly if a second process attempts to create a new lock file with
  # the same name as the deleted, hidden one.
  rm -- "$ABS_LOCK_FILENAME"

  echo "Done. Note that log file \"$ABS_LOG_FILENAME\" has been created."

else

  echo "Done. No log file has been created."

fi

exit "$CMD_EXIT_CODE"
