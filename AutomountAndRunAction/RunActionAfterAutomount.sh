#!/bin/bash

# Automated backup example script.
#
# Whenever a disk is attached, this script is triggered twice for each detected filesystem.
#
# On the first invocation, the filesystem is already mounted and this script can perform
# its main action, which is usually creating or updating a backup on that filesystem.
# Typically, the user is notified that the backup has started.
#
# On the second invocation, the filesystem is no longer mounted, so this script can
# notify the user that the backup is complete and it is now safe to remove the disk.
#
# The reason behind the split is that this script can run with restricted rights
# on an unprivileged user account, as it does not need to mount or unmount filesystems.
# Besides, if this script fails, the filesystem will always be unmounted by the caller.
# This separation of responsibilities makes implementation easier, reducing the risk
# of disk corruption. The drawback is the complication of storing the necessary state
# in the temporary directory for the second invocation.
#
# The error-handling strategy is as follows:
#
# - Any error at top-level should make this script fail.
#   That will make the calling systemd service fail, probably alerting
#   the system administrator that something went wrong.
#   An example of a top-level error is failing to send an e-mail.
#   There will be no second invocation if this script fails.
#
# - Errors during the operation itself (such as when creating a backup) should not make
#   this script fail. The error should be stored in the temporary directory,
#   and the user should be notified of the operation failure later on,
#   when this script runs the second time (when it is safe to remove the disk).
#
# Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r THIS_SCRIPT_FILENAME="$0"

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


declare -r LF=$'\n'

declare -r MAIL_TOOL="mail"

SendMail ()
{
  local -r RECIPIENT="$1"
  local -r TITLE="$2"
  local -r BODY="$3"

  local CMD
  printf -v CMD \
         "%q -s %q -- %q" \
         "$MAIL_TOOL" \
         "$TITLE" \
         "$RECIPIENT"

  echo "$CMD"
  eval "$CMD" <<< "$BODY"
}


DoBackup ()
{
  # This is just an example of an action. Replace it with your own action.

  echo "Directory listing of the mount point:"
  ls -la "$MOUNT_POINT"

  local -r -i WAIT_SECOND_COUNT=2

  echo "Waiting for $WAIT_SECOND_COUNT second(s)..."

  for (( i=1;i<= WAIT_SECOND_COUNT; i++ )); do
    echo "Wait iteration $i."
    sleep 1
  done

  echo "Finished waiting."

  if true; then
    echo "Creating backup data simulation..."

    local -r    BACKUP_SIMULATION_FILENAME="$MOUNT_POINT/BackupDataSimulation.bin"
    local -r -i BACKUP_DATA_SIZE_MB=20

    dd if="/dev/urandom" bs=$(( 1000 * 1000 )) count=$BACKUP_DATA_SIZE_MB >"$BACKUP_SIMULATION_FILENAME"

    echo "Backup simulation finished."
  fi
}


PerformAction ()
{
  # Run the action in a subshell in order to capture an eventual error.
  # The drawback is that any variable set or modified inside the subshell will be lost.
  # Alternatively, we coud run an external script.

  set +o errexit

  (
    set -o errexit
    set -o nounset
    set -o pipefail

    DoBackup
  )

  local -r -i ACTION_EXIT_CODE="$?"

  set -o errexit

  if (( ACTION_EXIT_CODE == 0 )); then
    echo "finished" > "$STATUS_FILENAME"
  else
    echo "failed" > "$STATUS_FILENAME"
  fi
}


OperationRun ()
{
  echo "Checking whether the configuration file exists..."

  if ! [ -f "$CONFIG_FILENAME" ]; then
    echo "No configuration file \"$CONFIG_FILENAME\" found, skipping the disk."
    echo "skipped" > "$STATUS_FILENAME"
    return
  fi


  # Here you should read the configuration file and check whether the disk
  # is configured for backup purposes.


  echo "Sending notification e-mail about operation start..."

  local HOSTNAME
  HOSTNAME=$(hostname)

  local MAIL_BODY=""

  MAIL_BODY+="Starting automated backup on host \"$HOSTNAME\", writing to: $MOUNT_POINT"
  MAIL_BODY+="${LF}"
  MAIL_BODY+="${LF}"

  # Cancelling an unattended, automated backup is tricky. For a start there is no easy GUI.
  # We do not implement any kind of clean request to cancel an ongoing backup,
  # so we rely on a simple SIGTERM signal which will just kill us (and hopefully all child processes too).
  #
  # Do not tell the user to stop the calling systemd service. The timeout for gracefully stopping
  # a systemd service is usually too short to flush the disk and unmount the filesystem,
  # so the service will probably get abruptly killed.
  #
  # The following code builds an advice for the user on how to cancel the ongoing backup.
  # There are 2 scenarios:
  #
  # a) If the parent script starts this script with "systemd-run --wait", we are running in a separate process group.
  #    Sending SIGTERM to the whole group looks like a good way to stop.
  #    Stopping the transient unit would send a SIGTERM to all processes too, but there would be a SIGKILL after a timeout.
  #
  # b) Otherwise, the parent script started us with "sudo --user".
  #    That will probably run this script in a separate process group too, but I haven't verified it yet.
  #    Sending SIGTERM to the whole group looks like a good way to stop too.
  #    In this case, we should probably modify this script to wait until all other children and grandchildren
  #    in the process group are gone. Otherwise, the caller script may assume that the backup has stopped
  #    only because the top-level process is gone, and unmounting the partition may fail
  #    with the usual "target is busy" error.

  MAIL_BODY+="In order to cancel the backup, send SIGTERM to process group $BASHPID like this: kill -SIGTERM -$BASHPID"

  SendMail "$MAIL_RECIPIENT" "Automated backup started" "$MAIL_BODY"

  echo "started" > "$STATUS_FILENAME"


  # Use a non-zero value here only for development and test purposes.
  declare -r -i SIGTERM_MYSELF_IN_NUMBER_OF_SECONDS=0
  if (( SIGTERM_MYSELF_IN_NUMBER_OF_SECONDS != 0 )); then

    local SIGTERM_CMD

    SIGTERM_CMD="sleep $SIGTERM_MYSELF_IN_NUMBER_OF_SECONDS && pstree --show-pgids $BASHPID && echo 'Sending myself SIGTERM...' && kill -SIGTERM $BASHPID &"
    echo "$SIGTERM_CMD"
    eval "$SIGTERM_CMD"

  fi

  # Redirect stdin to </dev/null . Otherwise, something my prompt the user,
  # and the operation is meant to run unattended.

  PerformAction 2>&1 </dev/null | tee "$LOG_FILENAME"
}


OperationNotify ()
{
  echo "Reading status from \"$STATUS_FILENAME\"..."

  local MAIL_TITLE
  local MAIL_BODY=""

  local STATUS

  STATUS="$(<"$STATUS_FILENAME")"

  case "$STATUS" in

    skipped)  echo "Nothing to notify."
              return;;

    started)  # We haven't got information about the exact failure reason.
              # This status should actually never happen if this script is robustly written.
              MAIL_TITLE="Automated backup failed"
              MAIL_BODY+="The automated backup failed. This error should never happen. Consult the log for details.";;

    finished) MAIL_TITLE="Automated backup finished successfully"
              MAIL_BODY+="The automated backup finished successfully.";;

    failed)   MAIL_TITLE="Automated backup failed"
              MAIL_BODY+="The automated backup failed.";;

    *) abort "Unknown status \"$STATUS\".";;
  esac

  MAIL_BODY+="${LF}"
  MAIL_BODY+="${LF}"
  MAIL_BODY+="You can remove the disk now."

  declare -r -i LINE_COUNT=20

  MAIL_BODY+="${LF}"
  MAIL_BODY+="${LF}"
  MAIL_BODY+="The last $LINE_COUNT lines of the log are:"
  MAIL_BODY+="${LF}"

  local LAST_LOG_LINES

  LAST_LOG_LINES="$(tail --lines="$LINE_COUNT" -- "$LOG_FILENAME")"

  MAIL_BODY+="$LAST_LOG_LINES"

  SendMail "$MAIL_RECIPIENT" "$MAIL_TITLE" "$MAIL_BODY"
}


# ------ Entry point ------

printf "Script %q has started.\n" "$THIS_SCRIPT_FILENAME"

# Record environment information. Use only for testing purposes.
if false; then
  ./program-argument-printer.pl "$@"
fi

if (( UID == 0 )); then
  abort "The user ID is zero, are you running this script as root?"
fi

if (( $# != 3 )); then
  abort "Invalid command-line arguments."
fi

declare -r OPERATION="$1"
declare -r MOUNT_POINT="$2"
declare -r TMP_DIRNAME="$3"

declare -r CONFIG_FILENAME="$MOUNT_POINT/AutomountAction.config"

# The recipient e-mail adress could come from the configuration file on the just-attached disk.
declare -r MAIL_RECIPIENT="user@example.com"

declare -r STATUS_FILENAME="$TMP_DIRNAME/Status.txt"
declare -r LOG_FILENAME="$TMP_DIRNAME/Log.txt"

case "$OPERATION" in
  run) OperationRun;;
  notify) OperationNotify;;
  *) abort "Unknown operation \"$OPERATION\"."
esac

printf "Script %q has finished.\n" "$THIS_SCRIPT_FILENAME"
