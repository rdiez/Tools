#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


# Some desktops, like KDE, provide notifications that stay until you click them away. Then
# you may want to disable the pop-up message window notification.
# You should not disable this under Microsoft Windows, because taskbar notifications are not implemented yet on Windows.

ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION=true


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

FIXED_LOG_FILENAME=""  # If not empty: Please enter here just a filename without dir paths, see LOG_FILES_DIR above. LOG_FILENAME_PREFIX is then ignored.

LOG_FILENAME_PREFIX="BackgroundCommand-"  # This prefix is also used to find the files to delete during log file rotation.

ENABLE_LOG_FILE_ROTATION=true
MAX_LOG_FILE_COUNT=100  # Must be at least 1. However, a much higher value is recommended, because .lock files from other
                        # concurrent background.sh processes, and also orphaned .lock files left behind,
                        # are counted as normal .log files too for log rotation purposes.


# Here you can set the method this tool uses to run processes with a lower priority:
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
# - Method "none" does not modify the child process' priority.

LOW_PRIORITY_METHOD="nice"

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

CHRT_PRIORITY="--batch 0"


#  ----- You probably do not need to modify anything beyond this point -----

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2017 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool runs the given process with a low priority under a combination of ('time' + 'tee') commands and displays a visual notification when finished."
  echo
  echo "The visual notification consists of a transient desktop taskbar indication (if command 'notify-send' is installed) and a permanent message box (a window that pops up). If you are sitting in front of the screen, the taskbar notification should catch your attention, even if the message box remains hidden beneath other windows. Should you miss the notification, the message box remains there until manually closed. If your desktop environment makes it hard to miss notifications, you can disable the message box, see ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION in this script's source code."
  echo
  echo "This tool is useful in the following scenario:"
  echo "- You need to run a long process, such as copying a large number of files or recompiling a big software project."
  echo "- You want to carry on using the computer for other tasks. That long process should run with a low CPU and/or disk priority in the background. By default, the process' priority is reduced to $NICE_TARGET_PRIORITY with 'nice', but you can switch to 'ionice' or 'chrt', see variable LOW_PRIORITY_METHOD in this script's source code for more information."
  echo "- You want to leave the process' console (or emacs frame) open, in case you want to check its progress in the meantime."
  echo "- You might inadvertently close the console window at the end, so you need a log file with all the console output for future reference (the 'tee' command). You can choose where the log files land and whether they rotate, see LOG_FILES_DIR in this script's source code."
  echo "- You may not notice when the process has completed, so you would like a visible notification in your desktop environment (like KDE or Xfce)."
  echo "- You would like to know immediately if the process succeeded or failed (an exit code of zero would mean success)."
  echo "- You want to know how long the process took, in order to have an idea of how long it may take the next time around (the 'time' command)."
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
  echo
  echo "Usage examples:"
  echo "  ./$SCRIPT_NAME -- echo \"Long process runs here...\""
  echo "  ./$SCRIPT_NAME -- sh -c \"exit 5\""
  echo
  echo "Caveat: If you start several instances of this script and you are using a fixed log filename (without log file rotation), you should do it from different directories. This script attempts to detect such a situation by creating a temporary lock file named after the log file and obtaining an advisory lock on it with flock (which depending on the underlying filesystem may have no effect)."
  echo
  echo "Exit status: Same as the command executed. Note that this script assumes that 0 means success."
  echo
  echo "Still to do:"
  echo "- This script could take optional parameters with the name of the log file, the 'nice' level and the visual notification method."
  echo "- Linux 'cgroups', if available, would provide a better CPU and/or disk prioritisation."
  echo "- Under Cygwin on Windows there is not taskbar notification yet, only the message box is displayed. I could not find an easy way to create a taskbar notification with a .vbs or similar script."
  echo "- Log file rotation could be smarter: by global size, by date or combination of both."
  echo "- Log files could be automatically compressed."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license ()
{
cat - <<EOF

Copyright (c) 2011-2014 R. Diez

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

  FILE_LIST="$(find "$FIND_DIR" -maxdepth 1 ! -name $'*\n*' -type f -name "$LOG_FILENAME_PREFIX*" | sort)"
  FILE_COUNT="$(echo "$FILE_LIST" | wc --lines)"

  if false; then
    printf "FILE_LIST:\n%s\n" "$FILE_LIST"
    echo "FILE_COUNT: $FILE_COUNT"
  fi

  if (( FILE_COUNT + 1 > MAX_LOG_FILE_COUNT )); then
    FILE_COUNT_TO_DELETE=$(( FILE_COUNT + 1 - MAX_LOG_FILE_COUNT ))

    if false; then
      echo "FILE_COUNT_TO_DELETE: $FILE_COUNT_TO_DELETE"
    fi

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


display_notification()
{
  local TITLE="$1"
  local TEXT="$2"
  local LOG_FILENAME="$3"

  echo "$TEXT"

  if [[ $OSTYPE = "cygwin" ]]
  then

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

    if type "$NOTIFY_SEND_TOOL" >/dev/null 2>&1 ;
    then
      "$NOTIFY_SEND_TOOL" "$TITLE"
    else
      echo "Note: The '$NOTIFY_SEND_TOOL' tool is not installed, therefore no desktop pop-up notification will be issued. You may have to install this tool with your Operating System's package manager. For example, under Ubuntu the associated package is called \"libnotify-bin\"."
    fi

    if $ENABLE_POP_UP_MESSAGE_BOX_NOTIFICATION; then
      echo "Waiting for the user to close the notification message box window..."
      # Remember that, if the user closes the window without pressing the OK button, the exit status is non-zero.
      # That is the reason why there is a "|| true" at the end.
      echo -e "$TEXT\n\nLog file: $LOG_FILENAME" | "$UNIX_MSG_TOOL" -title "$TITLE" -file - || true
    fi
  fi
}


# ----------- Entry point -----------

VERSION_NUMBER="2.10"
SCRIPT_NAME="background.sh"


if [ $# -lt 1 ]; then
  echo
  echo "You need to specify at least one argument. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
fi


case "$1" in

  --help)
    display_help
    exit $EXIT_CODE_SUCCESS;;

  --license)
    display_license
    exit $EXIT_CODE_SUCCESS;;

  --version)
    echo "$VERSION_NUMBER"
    exit $EXIT_CODE_SUCCESS;;

  --) shift;;

  --*) abort "Unknown option \"$1\".";;

esac

if [ $# -eq 0 ]; then
  echo
  echo "No command specified. Run this tool with the --help option for usage information."
  echo
  exit $EXIT_CODE_ERROR
fi


# Check whether the external 'time' command is available. Bash' internal 'time' command does not support the '-f' argument.
# Besides, Bash has a quirk that may bite you: 'time' is a keyword and only works if it's the first keyword in the command string.
# Note that the Cygwin environment tends not to install the external 'time' command by default,
# so it is likely that it's not present.
# Instead of 'time', we could use /proc/uptime and calculate the elapsed time in this script. Older versions of Cygwin
# did not have /proc/uptime, but it's there since at least a few years ago.

set +o errexit
EXTERNAL_TIME_COMMAND="$(which time)"
EXTERNAL_TIME_COMMAND_EXIT_CODE="$?"
set -o errexit

if [ $EXTERNAL_TIME_COMMAND_EXIT_CODE -ne 0 ]; then
  abort "The external 'time' command was not found. You may have to install it with your Operating System's package manager. For example, under Cygwin the associated package is called \"time\", and its description is \"The GNU time command\"."
fi


# Notification procedure:
# - Under Unix, use 'notify-send' if available to display a desktop notification, which normally
#   appears at the bottom right corner over the taskbar. In addition to that optional short-lived
#   notification, open a message box with 'gxmessage' that the user must manually close. That is
#   in case the user was not sitting in front of the screen when the temporary notification popped up.
# - Under Cygwin, use a native Windows script instead for notification purposes.
#   Desktop pop-up notifications are not implemented yet, you only get the message box.

NOTIFY_SEND_TOOL="notify-send"

UNIX_MSG_TOOL="gxmessage"

if ! [[ $OSTYPE = "cygwin" ]]; then
  command -v "$UNIX_MSG_TOOL" >/dev/null 2>&1  ||  abort "Tool '$UNIX_MSG_TOOL' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu the associated package is called \"gxmessage\", and its description is \"an xmessage clone based on GTK+\"."
fi


if [[ $OSTYPE = "cygwin" ]]
then
  # Even though Cygwin's GNU 'time' reports the same 1.7 version as under Linux, it does not have a '--quiet' argument.
  TIME_ARG_QUIET=""
else
  # Command-line switch '--quiet' suppresses the message "Command exited with non-zero status x"
  # upon non-zero exit codes. This script will print its own message about the exit code at the end.
  TIME_ARG_QUIET="--quiet"
fi


case "$LOW_PRIORITY_METHOD" in
  nice)
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


# Rotating the log files can take some time. Print some message so that the user knows that something
# is going on.
printf "\nRunning command with low priority: "
echo "$@"


if [[ $LOG_FILES_DIR == "" ]]; then
  ABS_LOG_FILES_DIR="$(readlink --canonicalize --verbose "$PWD")"
else
  ABS_LOG_FILES_DIR="$(readlink --canonicalize --verbose "$LOG_FILES_DIR")"
  mkdir --parents -- "$ABS_LOG_FILES_DIR"
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
  printf -v LOG_FILENAME_MKTEMP_FMT "$LOG_FILENAME_PREFIX%(%F-%H-%M-%S)T-XXXXXXXXXX.log"

  LOG_FILENAME="$(mktemp --tmpdir="$ABS_LOG_FILES_DIR" "$LOG_FILENAME_MKTEMP_FMT")"
else
  LOG_FILENAME="$ABS_LOG_FILES_DIR/$FIXED_LOG_FILENAME"
fi

LOCK_FILENAME="$LOG_FILENAME.lock"

ABS_LOG_FILENAME="$(readlink --canonicalize --verbose "$LOG_FILENAME")"
ABS_LOCK_FILENAME="$(readlink --canonicalize --verbose "$LOCK_FILENAME")"

if false; then
  echo "ABS_LOG_FILENAME: $LOG_FILENAME"
  echo "ABS_LOCK_FILENAME: $LOCK_FILENAME"
fi

create_lock_file
lock_lock_file

echo "The log file is: $ABS_LOG_FILENAME"
printf "\n"

{
  printf "Running command: "
  echo "$@"
  echo
} >>"$ABS_LOG_FILENAME"


set +o errexit
set +o pipefail


case "$LOW_PRIORITY_METHOD" in
  none)        "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  "$@" 2>&1 | tee --append -- "$ABS_LOG_FILENAME";;
  nice)        "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  nice -n $NICE_DELTA -- "$@" 2>&1 | tee --append -- "$ABS_LOG_FILENAME";;
  ionice)      "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  ionice --class $IONICE_CLASS --classdata $IONICE_PRIORITY -- "$@" 2>&1 | tee --append -- "$ABS_LOG_FILENAME";;
  ionice+chrt) "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  ionice --class $IONICE_CLASS --classdata $IONICE_PRIORITY -- chrt $CHRT_PRIORITY "$@" 2>&1 | tee --append -- "$ABS_LOG_FILENAME";;
  *) abort "Unknown LOW_PRIORITY_METHOD \"$LOW_PRIORITY_METHOD\".";;
esac

# Copy the exit status array, or it will get lost when the next command executes.
declare -a CAPTURED_PIPESTATUS=( "${PIPESTATUS[@]}" )


set -o errexit
set -o pipefail


if [ ${#CAPTURED_PIPESTATUS[*]} -ne 2 ]; then
  abort "Internal error, unexpected pipeline status element count."
fi

if [ "${CAPTURED_PIPESTATUS[1]}" -ne 0 ]; then
  abort "The 'tee' command failed."
fi

CMD_EXIT_CODE="${CAPTURED_PIPESTATUS[0]}"

{
  printf "Finished running command: "
  echo "$@"
  printf "Command exit code: %s\n" "$CMD_EXIT_CODE"
} >>"$ABS_LOG_FILENAME"


printf "Finished running command: "
echo "$@"

if [ "$CMD_EXIT_CODE" -eq 0 ]; then
  display_notification "Background cmd OK" "The command finished successfully." "$ABS_LOG_FILENAME"
else
  display_notification "Background cmd FAILED" "The command failed with exit code $CMD_EXIT_CODE." "$ABS_LOG_FILENAME"
fi

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

exit "$CMD_EXIT_CODE"
