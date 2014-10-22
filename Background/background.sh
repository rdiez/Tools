#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Here you can set the method this tool uses to run processes with a lower priority:
# - Method "nice" uses "nice -n 15". This is normally the best choice, as it has an impact
#   on both CPU and disk priority.
# - Method "ionice" uses "ionice --class 2 --classdata 7".
#   Class 2 means "best-effort" and is equivalent to the default ionice priority.
#   Priority 7 is the lowest priority in the "best-effort" class.
#   This affects only disk I/O priority. You may want to switch to this method
#   if you are running long background calculations (like BOINC with SETI@home)
#   and you are using the "ondemand" CPU scaling governor with setting "ignore_nice_load"
#   enabled in order to keep your laptop from heating up and its fan from getting loud.
#   Otherwise, any process started with background.sh will run more slowly than
#   it probably should.
# - Method "none" does not set the child process' priority.

LOW_PRIORITY_METHOD="nice"

# If you are using "ignore_nice_load", and have adjusted your 'nice' level before,
# you may find it handy to check the current 'nice' level every time this script runs.
# This way, you will realise straight away if you have one 'nice' too much somewhere
# you do not remember. This script is actually designed to be used interactively
# in a normal scenario. If you (or some automated script) have adjusted the 'nice' level
# beforehand, the resulting processing priority will probably not be what you expect.

CHECK_NICE_LEVEL=false

VERSION_NUMBER="2.1"
LOG_FILENAME="BackgroundCommand.log"
ABS_LOG_FILENAME="$(readlink -f "$LOG_FILENAME")"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


display_help ()
{
  echo
  echo "background.sh version $VERSION_NUMBER"
  echo "Copyright (c) 2011-2014 R. Diez - Licensed under the GNU AGPLv3"
  echo
  echo "This tool runs the given process with a low priority under a combination of ('time' + 'tee') commands and displays a visual notification when finished."
  echo
  echo "The visual notification consists of a transient desktop taskbar indication (if command 'notify-send' is installed) and a permanent modal message box. If you are sitting in front of the screen, the taskbar notification should catch your attention, even if the dialog box remains hidden beneath other windows. Should you miss the notification, the dialog box remains there until manually closed."
  echo
  echo "This tool is useful in the following scenario:"
  echo "- You need to run a long process, such as copying a large number of files or recompiling a big software project."
  echo "- You want to carry on using the computer for other tasks. That long process should run with a low CPU and/or disk priority in the background. By default, the process' priority is reduced with 'nice -n 15', but you can switch to 'ionice', see variable LOW_PRIORITY_METHOD in this script's source code for more information."
  echo "- You want to leave the process' console (or emacs frame) open, in case you want to check its progress in the meantime."
  echo "- You might inadvertently close the console window at the end, so you need a log file with all the console output for future reference (the 'tee' command)."
  echo "- You may not notice when the process has completed, so you would like a visible notification in your windowing environment (like KDE)."
  echo "- You would like to know immediately if the process succeeded or failed (an exit code of zero would mean success)."
  echo "- You want to know how long the process took, in order to have an idea of how long it may take the next time around (the 'time' command)."
  echo "- You want all that functionality conveniently packaged in a script that takes care of all the details."
  echo "- All that should work under Cygwin on Windows too."
  echo
  echo "Syntax:"
  echo "  background.sh <options...> <--> command <command arguments...>"
  echo  
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo
  echo "Usage examples:"
  echo "  ./background.sh -- echo \"Long process runs here...\""
  echo "  ./background.sh -- sh -c \"exit 5\""
  echo
  echo "Caveat: If you start several instances of this script, you should do it from different directories, as the log filename is hard-coded to \"$LOG_FILENAME\" and it will be overwritten each time."
  echo
  echo "Exit status: Same as the command executed. Note that this script assumes that 0 means success."
  echo
  echo "Still to do:"
  echo "- This script could take optional parameters with the name of the log file, the 'nice' level and the visual notification method."
  echo "- Linux 'cgroups', if available, would provide a better CPU and/or disk prioritisation."
  echo "- Under Cygwin on Windows there is not taskbar notification yet, only the message box is displayed."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
}


display_license()
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


if [ $# -lt 1 ]; then
  echo
  echo "You need to specify at least an argument. Run this tool with the --help option for usage information."
  echo
  exit 1
fi


case "$1" in
  --help)
    display_help
    exit 0;;
  --license)
    display_license
    exit 0;;
  --version)
    echo "$VERSION_NUMBER"
    exit 0;;
  --) shift;;
  --*) abort "Unknown option \"$1\".";;
esac


# Check whether the external 'time' command is available. bash' internal 'time' command does not support the '-f' argument.
# Besides, bash has a quirk that may bite you: 'time' is a keyword and only works if it's the first keyword in the command string.
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

if $CHECK_NICE_LEVEL; then
  declare -i CURRENT_NICE_LEVEL="$(nice)"
  declare -i EXPECTED_NICE_LEVEL=0

  if (( CURRENT_NICE_LEVEL != EXPECTED_NICE_LEVEL )); then
    abort "The current 'nice' level of $CURRENT_NICE_LEVEL does not match the expected value of $EXPECTED_NICE_LEVEL."
  fi
fi


# Notification procedure:
# - Under Unix, use 'notify-send' if available to display a desktop notification, which normally
#   appears at the bottom right corner over the taskbar. In addition to that optional short-lived
#   notification, open a dialog box with 'gxmessage' that the user must manually close. That is
#   in case the user was not sitting in front of the screen when the temporary notification popped up.
# - Under Cygwin, use a native Windows script instead for notification purposes.
#   Desktop pop-up notifications are not implemented yet, you only get the dialog box.

NOTIFY_SEND_TOOL="notify-send"

UNIX_MSG_TOOL="gxmessage"

if ! [[ $OSTYPE = "cygwin" ]]; then
  if [ ! "$(command -v "$UNIX_MSG_TOOL")" >/dev/null 2>&1 ]; then
    abort "Tool '$UNIX_MSG_TOOL' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu the associated package is called \"gxmessage\", and its description is \"an xmessage clone based on GTK+\"."
  fi
fi

display_notification()
{
  TITLE="$1"
  TEXT="$2"
  LOG_FILENAME="$3"

  echo "$TEXT"

  if [[ $OSTYPE = "cygwin" ]]
  then

    TMP_VBS_FILENAME="$(mktemp --tmpdir "tmp.background.sh.XXXXXXXXXX.vbs")"
    cat >"$TMP_VBS_FILENAME" <<EOF
Option Explicit
Dim args
Set args = WScript.Arguments
MsgBox args(1) & vbCrLf & vbCrLf & "Log file: " & args(2), vbOKOnly, args(0)
WScript.Quit(0) 
EOF
    echo "Waiting for the user to close the notification dialog window..."
    # Here we cross the line between the Unix and the Windows world. The command-line argument escaping
    # is a little iffy at this point, but the title and the text are not user-defined, but hard-coded
    # in this script. Therefore, this simplified string argument passing should be OK.
    cygstart --wait "$TMP_VBS_FILENAME" \"$TITLE\" \"$TEXT\" \"$LOG_FILENAME\"
    rm "$TMP_VBS_FILENAME"

  else
  
    if type "$NOTIFY_SEND_TOOL" >/dev/null 2>&1 ;
    then
      "$NOTIFY_SEND_TOOL" "$TITLE"
    else
      echo "Note: The '$NOTIFY_SEND_TOOL' tool is not installed, therefore no desktop pop-up notification will be issued. You may have to install this tool with your Operating System's package manager. For example, under Ubuntu the associated package is called \"libnotify-bin\"."
    fi

    echo "Waiting for the user to close the notification dialog window..."
    # Remember that, if the user closes the window without pressing the OK button, the exit status is non-zero.
    echo -e "$TEXT\n\nLog file: $LOG_FILENAME" | "$UNIX_MSG_TOOL" -title "$TITLE" -file - || true
  fi
}


if [[ $OSTYPE = "cygwin" ]]
then
  # Even though Cygwin's GNU 'time' reports the same 1.7 version as under Linux, it does not have a '--quiet' argument.
  TIME_ARG_QUIET=""
else
  # Command-line switch '--quiet' suppresses the message "Command exited with non-zero status x"
  # upon non-zero exit codes. This script will print its own message about the exit code at the end.
  TIME_ARG_QUIET="--quiet"
fi


printf "\nRunning command with low priority: "
echo "$@"
printf "The log file is: %s"
echo "$LOG_FILENAME"
printf "\n"


set +o errexit
set +o pipefail

case "$LOW_PRIORITY_METHOD" in
  none) "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  "$@" 2>&1 | tee "$LOG_FILENAME";;
  nice) "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  nice -n 15 -- "$@" 2>&1 | tee "$LOG_FILENAME";;
  ionice) "$EXTERNAL_TIME_COMMAND" $TIME_ARG_QUIET -f "\nElapsed time running command: %E"  ionice --class 2 --classdata 7 --  "$@" 2>&1 | tee "$LOG_FILENAME";;
  *) abort "Unknown LOW_PRIORITY_METHOD \"$LOW_PRIORITY_METHOD\".";;
esac

# Copy the exit status array, or it will get lost when the next command executes.
declare -a CAPTURED_PIPESTATUS=( ${PIPESTATUS[*]} )

set -o errexit
set -o pipefail

if [ ${#CAPTURED_PIPESTATUS[*]} -ne 2 ]; then
  abort "Internal error, unexpected pipeline status element count."
fi

if [ ${CAPTURED_PIPESTATUS[1]} -ne 0 ]; then
  abort "The 'tee' command failed."
fi

CMD_EXIT_CODE="${CAPTURED_PIPESTATUS[0]}"

{
  printf "Finished running command: "
  echo "$@"
  printf "Command exit code: $CMD_EXIT_CODE\n"
} >>"$LOG_FILENAME"


printf "Finished running command: "
echo "$@"

if [ $CMD_EXIT_CODE -eq 0 ]; then
  display_notification "Background cmd OK" "The command finished successfully." "$ABS_LOG_FILENAME"
else
  display_notification "Background cmd FAILED" "The command failed with exit code $CMD_EXIT_CODE." "$ABS_LOG_FILENAME"
fi

echo "Done. Note that log file \"$LOG_FILENAME\" has been created."

exit "$CMD_EXIT_CODE"
