#!/bin/bash

# Script version 1.00.
#
# This script is a workaround for this annoying prompt under Ubuntu 22.04:
#   Pending update of "firefox" snap
#   Close the app to avoid disruptions (4 days left)
# Plenty of people on the Internet hat written about this usability issue.
#
# This script upgrades the Snaps for both Firefox and Chromium.
# You may have to adjust it for your needs.
#
# Example desktop launchers:
# - This example uses 'tee' to record the output of the process inside the new console:
#     "/home/rdiez/rdiez/Tools/RunInNewConsole/run-in-new-console.sh" --console-title="Snap Upgrade Firefox and Chromium" -- "\"$HOME/rdiez/Tools/SnapUpgradeFirefoxChromium/SnapUpgradeFirefoxChromium.sh\" 2>&1 | tee --output-error=exit -- \"$HOME/SnapUpgradeFirefoxChromium.log\""
# - Simple version:
#     "/home/rdiez/rdiez/Tools/RunInNewConsole/run-in-new-console.sh" --console-title="Snap Upgrade Firefox and Chromium" -- "\"$HOME/rdiez/Tools/SnapUpgradeFirefoxChromium/SnapUpgradeFirefoxChromium.sh\""
#
# Suggested icon for the desktop launcher:
#   https://github.com/ubuntu/yaru/blob/master/icons/src/fullcolor/default/apps/snap-store.svg
#   You will have to remove the small icon versions with Inkscape, and then under "Document Properties",
#   choose "Resize page to content...".
#
# You probably want to add a line like this to a file under /etc/sudoers.d :
#   %sudo ALL=(root) NOPASSWD: /usr/bin/snap refresh firefox chromium

# Copyright (c) 2022 R. Diez
# Licensed under the GNU Affero General Public License version 3.

set -o errexit
set -o nounset
set -o pipefail


declare -r -i EXIT_CODE_ERROR=1

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


prompt_for_confirmation ()
{
  local MSG="There are running instances of Firefox or Chromium. Kill them?"
  local OK_BUTTON_CAPTION="Kill running instances"

  # Unfortunately, there is no way to set the cancel button to be the default.
  local CMD
  printf -v CMD \
         "%q  --no-markup  --image dialog-question --title %q  --text %q  --button=%q:0  --button=gtk-cancel:1" \
         "$TOOL_YAD" \
         "Snap Upgrade Confirmation" \
         "$MSG" \
         "$OK_BUTTON_CAPTION!gtk-ok"

  if false; then
    echo "$CMD"
  fi

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) DID_USER_CANCEL=false ;;
    1|252)  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
       DID_USER_CANCEL=true ;;
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


# ----------- Entry point -----------

if (( $# != 0 )); then
  abort "This script takes no command-line arguments."
fi


declare -r TOOL_YAD="yad"

verify_tool_is_installed  "$TOOL_YAD" "yad"


echo "Checking whether there are running instances of Firefox or Chromium..."

declare -r PROCESS_REGEX="^(firefox|chrome)\$"

set +o errexit
pgrep --list-name -- "$PROCESS_REGEX" >/dev/null
PGREP_EXIT_CODE="$?"
set -o errexit

DID_USER_CANCEL=false
KILL_PROCESSES=false

case "$PGREP_EXIT_CODE" in
  0) echo "There are running instances. Prompting the user for confirmation..."
     prompt_for_confirmation
     KILL_PROCESSES=true
     ;;

  1) echo "There are no running instances."
      ;;

  *) abort "Unexpected exit code of $PGREP_EXIT_CODE from 'pgrep'."
esac


if $DID_USER_CANCEL; then

  echo "The user cancelled the operation."

else

  if $KILL_PROCESSES; then

    echo "Killing running instances of Firefox and Chromium..."

    set +o errexit
    pkill --signal=SIGTERM -- "$PROCESS_REGEX" >/dev/null
    PKILL_EXIT_CODE="$?"
    set -o errexit

    case "$PKILL_EXIT_CODE" in
      0|1) # Nothing to do here.
           ;;
      *) abort "Unexpected exit code of $PKILL_EXIT_CODE from 'pkill'."
    esac

  fi

  sudo snap refresh firefox chromium
  echo "Finished upgrading the Snap browser packages."
fi
