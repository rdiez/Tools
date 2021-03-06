#!/bin/bash

# update-several-mirrors.sh script template version 2.04
#
# This script template shows how to call update-file-mirror-by-modification-time.sh
# several times in order to update the corresponding number of online backup mirrors.
#
# For extra comfort, you can remind and notify the user during the process.
#
# It is probably most convenient to run this script with "background.sh", so that
# it runs with low priority and you get a visual notification when finished or when failed.
#
# Copyright (c) 2015-2018 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


declare -r SHOULD_DISPLAY_REMINDERS=true


declare -r SCRIPT_NAME="update-several-mirrors.sh"

declare -r UPDATE_MIRROR_SCRIPT="./update-file-mirror-by-modification-time.sh"

declare -r TOOL_ZENITY="zenity"
declare -r TOOL_YAD="yad"
declare -r TOOL_NOTIFY_SEND="notify-send"

# Zenity has window size issues with GTK 3 and has become unusable lately.
# Therefore, YAD is recommended instead.
declare -r DIALOG_METHOD="yad"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -a CHILD_PROCESSES=()


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit "$EXIT_CODE_ERROR"
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


update_mirror ()
{
  command -v "$UPDATE_MIRROR_SCRIPT" >/dev/null 2>&1  ||  abort "Cannot find script '$UPDATE_MIRROR_SCRIPT'."

  local CMD
  printf -v CMD "%q  %q  %q"  "$UPDATE_MIRROR_SCRIPT"  "$1"  "$2"

  echo "$CMD"
  eval "$CMD"
}


start_meld ()
{
  local SRC
  local DEST
  local MELD_CMD

  printf -v SRC  "%q" "$1"
  printf -v DEST "%q" "$2"

  MELD_CMD="meld  $SRC  $DEST"

  echo "$MELD_CMD"
  eval "$MELD_CMD" &

  CHILD_PROCESSES+=("$!")
}


display_confirmation_zenity ()
{
  local TITLE="$1"
  local OK_BUTTON_CAPTION="$2"
  local MSG="$3"

  # Unfortunately, there is no way to set the cancel button to be the default.
  local CMD
  printf -v CMD  "%q --no-markup  --question --title %q  --text %q  --ok-label %q  --cancel-label \"Cancel\""  "$TOOL_ZENITY"  "$TITLE"  "$MSG"  "$OK_BUTTON_CAPTION"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1) echo
       echo "The user cancelled the process."
       exit "$EXIT_CODE_SUCCESS";;
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_ZENITY\"." ;;
  esac
}


display_reminder_zenity ()
{
  local TITLE="$1"
  local MSG="$2"

  local CMD
  printf -v CMD  "%q --no-markup  --info  --title %q  --text %q"  "$TOOL_ZENITY"  "$TITLE"  "$MSG"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1) : ;;  # If the user presses the ESC key, or closes the window, Zenity yields an exit code of 1.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_ZENITY\"." ;;
  esac
}


display_confirmation_yad ()
{
  local TITLE="$1"
  local OK_BUTTON_CAPTION="$2"
  local MSG="$3"

  # Unfortunately, there is no way to set the cancel button to be the default.
  # Option --fixed is a work-around to excessively tall windows with YAD version 0.38.2 (GTK+ 3.22.30).
  local CMD
  printf -v CMD \
         "%q --fixed --no-markup  --image dialog-question --title %q  --text %q  --button=%q:0  --button=gtk-cancel:1" \
         "$TOOL_YAD" \
         "$TITLE" \
         "$MSG" \
         "$OK_BUTTON_CAPTION!gtk-ok"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1|252)  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
       echo
       echo "The user cancelled the process."
       exit "$EXIT_CODE_SUCCESS";;
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


display_reminder_yad ()
{
  local TITLE="$1"
  local MSG="$2"

  # Option --fixed is a work-around to excessively tall windows with YAD version 0.38.2 (GTK+ 3.22.30).
  local CMD
  printf -v CMD \
         "%q --fixed --no-markup  --image dialog-information  --title %q  --text %q --button=gtk-ok:0" \
         "$TOOL_YAD" \
         "$TITLE" \
         "$MSG"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0|252) : ;;  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


display_confirmation ()
{
  case "$DIALOG_METHOD" in
    zenity)  display_confirmation_zenity "$@";;
    yad)     display_confirmation_yad "$@";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac
}

display_reminder ()
{
  case "$DIALOG_METHOD" in
    zenity)  display_reminder_zenity "$@";;
    yad)     display_reminder_yad "$@";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac
}


display_desktop_notification ()
{
  local TITLE="$1"
  local HAS_FAILED="$2"

  if command -v "$TOOL_NOTIFY_SEND" >/dev/null 2>&1; then

    if $HAS_FAILED; then
      "$TOOL_NOTIFY_SEND" --icon=dialog-error       -- "$TITLE"
    else
      "$TOOL_NOTIFY_SEND" --icon=dialog-information -- "$TITLE"
    fi

  else
    echo "Note: The '$TOOL_NOTIFY_SEND' tool is not installed, therefore no desktop pop-up notification will be issued. You may have to install this tool with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"libnotify-bin\"."
  fi
}


notify_but_do_not_stop ()
{
  local MSG="$1"

  display_desktop_notification "$MSG" false

  display_reminder "Mirror Notification" "$MSG"  &

  CHILD_PROCESSES+=("$!")
}


# ----------- Entry point -----------

if $SHOULD_DISPLAY_REMINDERS; then
  case "$DIALOG_METHOD" in
    zenity)  verify_tool_is_installed  "$TOOL_ZENITY"  "zenity";;
    yad)     verify_tool_is_installed  "$TOOL_YAD"     "yad";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac
fi


SRC1="$HOME/src/src1"
DEST1="$HOME/dest/dest1"

SRC2="$HOME/src/src2"
DEST2="$HOME/dest/dest2"


# The mirroring process.
if true; then

  if $SHOULD_DISPLAY_REMINDERS; then
    BEGIN_REMINDERS="The mirroring process is about to begin:"$'\n'

    BEGIN_REMINDERS+="- Close Thunderbird."$'\n'
    BEGIN_REMINDERS+="- Close some other programs you often run that use files being mirrored."$'\n'
    BEGIN_REMINDERS+="- Place other reminders of yours here."

    display_confirmation "Mirror Reminder" "Start mirroring" "$BEGIN_REMINDERS"
  fi


  # Consider mirroring this script file too like this:
  printf -v CMD  "cp -- %q %q"  "$SCRIPT_NAME"  "$HOME/some/destination/dir"
  echo "$CMD"
  eval "$CMD"


  update_mirror "$SRC1" "$DEST1"

  if $SHOULD_DISPLAY_REMINDERS; then
    # If you want to mirror some files you are using at the moment, mirror them first,
    # so that you can start using those files again in as little time as possible.
    notify_but_do_not_stop "You can now reopen Thunderbird."
  fi

  update_mirror "$SRC2" "$DEST2"


  if $SHOULD_DISPLAY_REMINDERS; then

    display_desktop_notification "The mirroring process has finished" false


    END_REMINDERS="The mirroring process has finished:"$'\n'

    END_REMINDERS+="- Place other reminders of yours here."$'\n'
    END_REMINDERS+="- More reminders of yours."

    display_reminder "Mirror Reminder" "$END_REMINDERS"

  fi

fi


# Use these in order to manually verify the mirrors:
if false; then
  start_meld "$SRC1" "$DEST1"
  start_meld "$SRC2" "$DEST2"
fi


# Wait for all child processes to terminate.

declare -i CHILD_PROCESSES_ELEM_COUNT="${#CHILD_PROCESSES[@]}"

if (( CHILD_PROCESSES_ELEM_COUNT != 0 )); then

  echo "Waiting for all background child proccesses (like the notification windows) to terminate..."

  declare -i CHILD_PROCESS_FAIL_COUNT=0

  for JOB_ID in "${CHILD_PROCESSES[@]}"; do

    set +o errexit
    wait "$JOB_ID"
    WAIT_EXIT_CODE="$?"
    set -o errexit

    if (( WAIT_EXIT_CODE != 0 )); then
      (( ++CHILD_PROCESS_FAIL_COUNT ))
      # We could print here the failed command.
    fi

  done

  if (( CHILD_PROCESS_FAIL_COUNT != 0 )); then
    abort "$CHILD_PROCESS_FAIL_COUNT child processes have failed."
  fi

fi


echo "The mirroring process has finished."
