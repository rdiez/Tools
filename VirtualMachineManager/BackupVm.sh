#!/bin/bash

# This script performs a cold backup of a libvirt virtual machine.
#
# Version 1.00.
#
# Usage:
#  ./BackupVm.sh <destination directory>
#
# If the virtual machine is already running, it shuts it down, and restarts it afterwards.
#
# The script asummes that all virtual disks are using QEMU's qcow2 format.
# Disk images are copied with qemu-img, so the resulting copy will usually shrink. Therefore,
# the target filesystem needs no sparse file support.
#
# The libvirt snapshot metadata is not backed up yet.
#
# The script's implementation is more robust than comparable scripts from the Internet. The whole script
# runs with error detection enabled. The elapsed time is printed after shuting down the virtual machine
# and after backing up a virtual disk, which helps measure performance.
#
# This script requires tool 'xmlstarlet'.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r EXIT_CODE_ERROR=1

declare -r CONNECTION_URI="qemu:///system"

declare -r VM_ID="UbuntuMATE1804-i386"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
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


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


check_if_vm_is_running ()
{
  # Set the LANG to a default value, so that the status you get is "running", etc. in English,
  # and not some localised/translated version.
  #
  # By the way, we are parsing a string meant for the user, which is not very robust.
  # But there does not seem to be any other easy way to query the status from a shell script.

  echo "Checking whether virtual machine \"$VM_ID\" is running..."

  local CMD
  printf -v CMD  "env LANG=C  virsh  --connect %q  domstate %q" "$CONNECTION_URI"  "$VM_ID"

  echo "$CMD"

  local STATUS
  STATUS="$(eval "$CMD")"

  case "$STATUS" in
    "running")  IS_VM_RUNNING=true;;
    "shut off") IS_VM_RUNNING=false;;
    *) abort "Unexepected status of \"$STATUS\".";;
  esac
}


start_vm ()
{
  echo "Starting virtual machine \"$VM_ID\"..."

  local CMD
  printf -v CMD  "virsh  --connect %q  start  %q" "$CONNECTION_URI"  "$VM_ID"

  echo "$CMD"
  eval "$CMD"
}


stop_vm ()
{
  echo "Shutting down virtual machine \"$VM_ID\"..."

  local CMD

  # Command 'shutdown' via ACPI will not work if the VM is stuck in the GRUB bootloader.
  printf -v CMD  "virsh  --connect %q  shutdown  --mode acpi  %q"  "$CONNECTION_URI"  "$VM_ID"

  echo "$CMD"
  eval "$CMD"

  # It can take a long time to shutdown a Linux virtual machine. Sometimes systemd waits quite a long time
  # for some services to stop.
  local -r TIMEOUT=120

  # I cannot believe that virsh command "shutdown" does not have a "--wait-for=seconds" option,
  # or some other way to wait until a virtual machine has stopped.
  # Just think of how many people have implemented the kind of waiting loop below.

  local START_UPTIME
  local ELAPSED_SECONDS

  read_uptime_as_integer
  local -r START_UPTIME="$UPTIME"

  while true; do

    check_if_vm_is_running

    read_uptime_as_integer

    ELAPSED_SECONDS=$(( UPTIME - START_UPTIME ))

    if ! $IS_VM_RUNNING; then
      break;
    fi

    if (( ELAPSED_SECONDS >= TIMEOUT )); then
      abort "Timeout waiting for the virtual machine \"$VM_ID\" to stop."
    fi

    sleep 1

  done

  get_human_friendly_elapsed_time "$ELAPSED_SECONDS"
  echo "Virtual machine \"$VM_ID\" has been shutdown, time to shutdown: $ELAPSED_TIME_STR"
}


backup_up_vm_disk ()
{
  local -r DISK_FILENAME="$1"

  echo "Backing up VM disk \"$DISK_FILENAME\"..."

  read_uptime_as_integer
  local -r START_UPTIME="$UPTIME"


  # Most disks will be in .qcow2 format, which tend to be heavily sparse.
  # Tool 'cp' normally automatically detects sparse files and can copies them efficiently. Otherwise, try adding option "--sparse=always".
  # Note that some filesystem, like eCryptfs, do not support sparse files.
  # Using "qemu-img convert" to copy the image has the nice side-effect that the copy is optimised (shrinks),
  # no matter whether the underlying filesystem supports sparse files or not.

  local -r NAME_ONLY="${DISK_FILENAME##*/}"

  # This would use the 'cp' command:
  #   printf -v CMD  "cp -- %q %q"  "$DISK_FILENAME"  "$DEST_DIRNAME/$NAME_ONLY"

  # Option '-c' would compress the data blocks. Compression is not very good (based on zlib).
  printf -v CMD  "qemu-img  convert  -O qcow2  -- %q  %q"  "$DISK_FILENAME"  "$DEST_DIRNAME/$NAME_ONLY"

  echo "$CMD"
  eval "$CMD"

  read_uptime_as_integer
  get_human_friendly_elapsed_time "$(( UPTIME - START_UPTIME ))"

  echo "Finished backing up the VM disk, time to backup: $ELAPSED_TIME_STR"
}


# ----------- Entry point -----------

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments."
fi

declare -r DEST_DIRNAME="$1"


# We are doing a 'cold' backup: shutdown the VM if already running, back it up, and restart the VM if was running.
# There are alternative ways to do such backups, see options --atomic and --quiesce, and also command 'virsh domfsfreeze'.
# However, cold backups have advantages:
# 1) You make sure the operating system restarts every now and then, which tends to help reliability.
# 2) You can change the VM configuration (virtual hardware), and the backups will mostly start fine.
#    If you save the running state to RAM, all virtual hardware must be the same,
#    which can be inconvenient in some situations.


check_if_vm_is_running

declare -r WAS_VM_RUNNING="$IS_VM_RUNNING"

if $WAS_VM_RUNNING; then
  stop_vm
fi

echo "Backing up VM configuration..."

declare -r XML_FILENAME="$DEST_DIRNAME/$VM_ID.xml"

printf -v CMD  "virsh  --connect %q  dumpxml  %q >%q"  "$CONNECTION_URI"  "$VM_ID"  "$XML_FILENAME"

echo "$CMD"
eval "$CMD"


# This script does not copy the necessary snapshot metadata yet.
# To implement this, look at commands "virsh snapshot-dumpxml --security-info"
# and "virsh snapshot-create --redefine". You may also want to backup and restore which snapshot
# is the current one.


# The following code parses the virtual machine XML configuration file.
# Alternatively, we could parse the output of "virsh domblklist --details". For example: awk '/^[[:space:]]*file[[:space:]]+disk/ {print "imgs["$3"]="$4}'

echo "Extracting disk files..."

verify_tool_is_installed "xmlstarlet" "xmlstarlet"

# This search expression could no doubt be improved.
declare -r SEARCH_EXPRESSION="/domain/devices/disk[@device='disk']/source/@file"

printf -v CMD \
       "xmlstarlet sel --template --value-of %q  %q" \
       "$SEARCH_EXPRESSION" \
       "$XML_FILENAME"

echo "$CMD"
DISK_FILENAMES_AS_TEXT="$(eval "$CMD")"

declare -a DISK_FILENAMES
readarray -t  DISK_FILENAMES <<<"$DISK_FILENAMES_AS_TEXT"

# When developing this script, sometimes you want to skip backing up the disks,
# because it can be very slow.
declare SKIP_DISK_BACKUPS=false

for FILENAME in "${DISK_FILENAMES[@]}"
do
  if $SKIP_DISK_BACKUPS; then
    echo "Skipping backup of \"$FILENAME\"."
  else
    backup_up_vm_disk "$FILENAME"
  fi
done

echo "Finished backing up VM disks."

if $WAS_VM_RUNNING; then
  start_vm
fi
