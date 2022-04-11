#!/bin/bash

# This script is triggered from a udev rule, via a systemd service, when a disk is attached.
# The script is called for each partition on the attached disk, and then it automounts
# the filesystem in the partition, runs some action on it, unmounts it and notifies the user.
#
# Copyright (c) 2022 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r THIS_SCRIPT_FILENAME="$0"

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


is_dir_empty ()
{
  shopt -s nullglob
  shopt -s dotglob  # Include hidden files.

  # Command 'local' is in a separate line, in order to prevent masking any error from the external command (or operation) invoked.
  local -a FILES
  FILES=( "$1"/* )

  if (( ${#FILES[@]} == 0 )); then
    return $BOOLEAN_TRUE
  else
    if false; then
      echo "Files found: ${FILES[*]}"
    fi
    return $BOOLEAN_FALSE
  fi
}


flush_disk_cache ()
{
  # If something tries to stop this systemd service, we will get a SIGTERM first,
  # and some time afterwards (by the default 90 seconds) a SIGKILL.
  # Therefore, stopping the service will often timeout in this routine,
  # because flushing the data to disk may take much longer than the systemd service stop timeout.
  #
  # Flushing the disk cache before unmounting may prevent timeouts while unmounting the partition.
  # If the backup process writes a lot of data to a slow external disk,
  # it can take minutes to flush it all out. Tool 'sync' has no timeouts, as far as I am aware.
  #
  # The process of unmounting should flush the cache automatically, but I am not sure whether
  # the time that this flushing takes is counted against the overall unmouting timeout.
  # Besides, if the unmounting fails with the usual "target is busy" error, it apparently fails
  # straight away, without flushing the cache first, so flushing beforehand seems a safer bet.
  # At least the backup data will have been written to disk when the user gets a notification
  # and attempts to detach the disk.
  # After all, the process holding the filesystem busy may only be reading from it.
  #
  # Note that, if the filesystem has already been unmounted at this point,
  # we may end up flushing the parent filesystem, and that has performance implications
  # for the rest of the system. Unfortunately, there seems to be no way to specify
  # a device to sync/flush. We could check upfront whether the filesystem is still mounted,
  # but there will always be a window of opportunity between the check and the flushing.

  echo "Flushing the disk cache..."

  local CMD

  printf -v CMD \
         "sync --file-system -- %q" \
         "$MOUNT_POINT"

  echo "$CMD"
  eval "$CMD"
}


unmount ()
{
  echo "Unmounting \"$MOUNT_POINT\"..."

  # Unmounting the filesystem is likely to fail every now and then.
  # It can easily happen if something is using the filesystem at the moment,
  # which shouldn't actually be the case with our automount scripts.
  #
  # If this poses many problems, we could retry a few times.
  # We could also use 'lsof' as follows to tell the user which processes are still using the filesystem:
  #    printf -v CMD \
  #         "lsof +f -- %q" \
  #         "$MOUNT_POINT"

  local CMD

  printf -v CMD \
         "systemd-mount --umount -- %q" \
         "$MOUNT_POINT"

  echo "$CMD"
  eval "$CMD"
}


CLEANUP_FLUSH_DISK_CACHE=false
CLEANUP_UNMOUNT=false
CLEANUP_DELETE_MOUNT_POINT=false
CLEANUP_DELETE_TMP_DIR=false

exit_cleanup ()
{
  # Cleaning up is a best-effort operation. Therefore,
  # if something fails, it should not prevent other clean-up steps.
  set +o errexit
  set +o pipefail

  if $CLEANUP_FLUSH_DISK_CACHE; then
    flush_disk_cache
  fi
 
  if $CLEANUP_UNMOUNT; then
    unmount
  fi

  # The mount point must be deleted after unmounting.
  if $CLEANUP_DELETE_MOUNT_POINT; then
    echo "Deleting mount point \"$MOUNT_POINT\"..."
    # Do not delete recursively, in case the partition is still mounted (because it failed to unmount).
    rmdir -- "$MOUNT_POINT"
  fi

  if $CLEANUP_DELETE_TMP_DIR; then
    echo "Deleting temporary directory \"$TMP_DIRNAME\"..."
    rm -rf -- "$TMP_DIRNAME"
  fi

  # Restore the usual error-handling flags. Instead of hard-coding these options,
  # we could require a modern version of Bash, so that we could use "local -" in order
  # to make such shell options are only local to the current function.
  set -o errexit
  set -o pipefail
}


WAS_EXIT_EXPECTED=false

exit_cleanup_trap ()
{
  if ! $WAS_EXIT_EXPECTED; then
    echo "Cleaning up after an unexpected script termination..."
  fi

  exit_cleanup

  if $WAS_EXIT_EXPECTED; then
    printf "Script %q has finished.\n" "$THIS_SCRIPT_FILENAME"

  else
    printf "Script %q has finished unexpectedly.\n" "$THIS_SCRIPT_FILENAME"
  fi
}


# ------ Entry Point ------

printf "Script %q has started.\n" "$THIS_SCRIPT_FILENAME"

# Print environment information. Use only for development and testing purposes.
if false; then
  ./program-argument-printer.pl "$@"
fi

if (( $# != 1 )); then
  abort "Invalid command-line arguments."
fi

# Example partition device name: /dev/sdb1
declare -r PARTITION_DEVICE_NAME="$1"

echo "Partition $PARTITION_DEVICE_NAME has been attached."

# Sometimes it is useful to disable all operations. Used mainly for development and testing purposes.
if false; then

  echo "Processing of attached partitions has been disabled, so skipping any further operations."
  exit 0

fi


# At this point, we could check whether systemd already knows the partition
# and will be mounting it automatically. Maybe you can just check whether a systemd mount unit
# with the right name exists. If that is the case, the disk or partition
# will probably be used for other purposes than triggering an automatic backup.
#
# Alternatively, we could check whether the new partition is listed in /etc/fstab, and skip it.
# Perhaps there is some program or API to check that, because the match criteria can be tricky.
# But keep in mind that systemd will automatically create mount units from fstab entries.


# Make sure that permissions for the mount point directory defined below are tight.
# Normally, only root should have write permissions on it.
#
# I did not want to mount somewhere under /tmp, because people tend to assume that everything there
# can be safely deleted, and, if an external disk is still mounted, somebody may then delete too much.
declare -r BASE_DIR="/MyAutomountAndRunAction"
declare -r BASE_MOUNT_DIR="$BASE_DIR/MountPoints"

# We do not want to automatically create the base mount directory,
# because the sysadmin will probably want to tight permissions on it.

if [ ! -d "$BASE_MOUNT_DIR" ]; then
  abort "Directory \"$BASE_MOUNT_DIR\" does not exist."
fi


# On Bash, EXIT traps are executed even after receiving a signal.
# This is important, because if you stop the systemd service with
#    sudo systemctl stop xxx@yyy.service
# this script will then receive a SIGTERM.
trap "exit_cleanup_trap" EXIT


# We create a temporary directory for the action script, because we will
# be running the script twice, so it needs to save at least enough state
# to notify the user in the second invocation.

declare -r THIS_SCRIPT_NAME_ONLY="${THIS_SCRIPT_FILENAME##*/}"

echo "Creating a temporary directory..."

TMP_DIRNAME="$(mktemp --directory --tmpdir -- "$THIS_SCRIPT_NAME_ONLY.XXXXXXXXXX")"

# There is actually a small window of opportunity here: if a signal comes in right after creating
# the directory, we may not clean it up. But we need TMP_DIRNAME before enabling its automatic deletion.
CLEANUP_DELETE_TMP_DIR=true

echo "Temporary directory created: $TMP_DIRNAME"


# About the username below: there must be a user group with the same name too, but that is usually the case on Linux.
declare -r USERNAME_FOR_ACTION="my-automount-action-user"

echo "Adjusting temporary directory permissions..."
chown "$USERNAME_FOR_ACTION:$USERNAME_FOR_ACTION" -- "$TMP_DIRNAME"


# We must not use the same escaping rules as systemd, we could write our own escaping routine.
ESCAPED_PARTITION_DEVICE_NAME="$(systemd-escape --path -- "$PARTITION_DEVICE_NAME")"

# Device names tend to repeat themselves, so we shouldn't be creating too many different mount point directories
# that could be orphaned in case of abrupt termination of this script.
declare -r MOUNT_POINT="$BASE_MOUNT_DIR/Automount-$ESCAPED_PARTITION_DEVICE_NAME"

if [ -d "$MOUNT_POINT" ]; then

  if ! is_dir_empty "$MOUNT_POINT"; then
    abort "Mount point \"$MOUNT_POINT\" already exists and is not empty (already mounted?). While not strictly a requirement for mounting purposes, this script does not expect a non-empty mount point."
  fi

  echo "Mount point \"$MOUNT_POINT\" already exists, which is unusual (orphaned?)."

  CLEANUP_DELETE_MOUNT_POINT=true
  
else

  # We do not actually need to create the mount point directory beforehand, for systemd-mount seems to do that if necessary.
  # However, it is not clearly documented, and other mount methods do require an existing mount point.

  echo "Creating mount point \"$MOUNT_POINT\"..."

  CLEANUP_DELETE_MOUNT_POINT=true

  mkdir -- "$MOUNT_POINT"

  # It is recommended that the mount point directory is read only.
  # This way, if mounting the filesystem fails, other processes will not inadvertently write to your local disk.
  #
  # Removing the execute ('x') permission is actually a stronger variant of "read only". With only the read permission ('r'),
  # you can list the files inside the directory, but you cannot access their dates, sizes or permissions.
  # In fact, removing the write ('w') permission is actually unnecessary, because 'w' has no effect without 'x'.
  chmod a-wx -- "$MOUNT_POINT"

fi


echo "Mounting the filesystem..."

# Apparently, systemd-mount works with FUSE filesystems too. I tested it with exFAT on a Linux kernel
# which did not have built-in support for exFAT (it did not appear in /proc/filesystems).
#
# With option '--discover', the system reads the partition label among other metadata, but we may not need that.
# But more importantly, option --discover checks straight away that the new device actually exists.
#
# We are using the 'automount' feature, which is different from the 'automount' functionally this script implements.
# systemd-mount's 'automount' means that the filesystem will be automatically unmounted
# after a period of inactivity. After all, we are mounting for a temporary activity, so if we fail to unmount
# later on for whatever reason, the system will do it for us (provided that nothing else accesses the mount point
# again). This feature should help minimise 'dirty' filesystems that have to be checked
# for errors the next time the disk is attached.
#
# For extra safety, we could mount as read-only first. Afer checking that the disk is actually configured
# for backup purposes, we could then (re)mount as read-write.

CLEANUP_UNMOUNT=true

printf -v CMD \
       "systemd-mount --owner=%q --discover --automount=yes --bind-device --collect -- %q  %q" \
       "$USERNAME_FOR_ACTION" \
       "$PARTITION_DEVICE_NAME" \
       "$MOUNT_POINT"

echo "$CMD"
eval "$CMD"

declare -r SCRIPT_TO_RUN="$BASE_DIR/RunActionAfterAutomount.sh"

echo "Running the action on the partition filesystem with script \"$SCRIPT_TO_RUN\"..."

CLEANUP_FLUSH_DISK_CACHE=true

if true; then

  # systemd-run executes the external script in a separate control group.
  # If the user decides to kill it, a separate control group makes it easier
  # to ensure that the external script and all of its child processes have actually
  # terminated before trying to unmount the filesystem afterwards.
  #
  # Beware that systemd-run has extra escaping requirements when not using '--scope',
  # so do not pass any suspect characters like '$', '%', '\', or ';' (among others) on
  # the command line below. For more information, see the "Quoting" section
  # in systemd.syntax(7) and this bug report:
  #   Surprising systemd-run quoting/escaping behaviour
  #   https://github.com/systemd/systemd/issues/22948
  #
  # Use --service-type=oneshot, because otherwise SIGTERM etc. will not be considered
  # a cause of failure. We lose the command's exit code, but we do not need it anyway.
  # For more information see this bug report:
  #   "systemd-run --wait" exit code if process killed by a signal
  #   https://github.com/systemd/systemd/issues/22812

  printf -v CMD \
          "systemd-run --service-type=oneshot --wait --collect --uid=%q -- %q %q %q %q" \
          "$USERNAME_FOR_ACTION" \
          "$SCRIPT_TO_RUN" \
          "run" \
          "$MOUNT_POINT" \
          "$TMP_DIRNAME"
else

  # Running the command directly is an option, but then it is hard to know
  # whether all child processes have actually terminated when the first child exists.
  # That often leads to error "target is busy" when trying to unmount the partition.
  
  printf -v CMD \
         "sudo --user=%q -- %q %q %q %q" \
         "$USERNAME_FOR_ACTION" \
         "$SCRIPT_TO_RUN" \
         "run" \
         "$MOUNT_POINT" \
         "$TMP_DIRNAME"
fi

echo "$CMD"
eval "$CMD"

echo "The action on the partition filesystem has finished."


# We need to unmount the partition before notifying the user. Otherwise, the user may detach the disk
# too early, while its partition is still being umounted.

flush_disk_cache

CLEANUP_FLUSH_DISK_CACHE=false

unmount

CLEANUP_UNMOUNT=false


echo "Notifying the user with script \"$SCRIPT_TO_RUN\"..."

printf -v CMD \
       "sudo --user=%q -- %q %q %q %q" \
       "$USERNAME_FOR_ACTION" \
       "$SCRIPT_TO_RUN" \
       "notify" \
       "$MOUNT_POINT" \
       "$TMP_DIRNAME"

echo "$CMD"
eval "$CMD"


WAS_EXIT_EXPECTED=true
# At this point, exit_cleanup_trap will run.
