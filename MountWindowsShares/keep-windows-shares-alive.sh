#!/bin/bash

# keep-windows-shares-alive.sh version 1.01
# Copyright (c) 2017 R. Diez - Licensed under the GNU AGPLv3
#
# Many Linux kernels have problems with SMB mounts. After a period of inactivity,
# CIFS connections are severed, and automatic reconnections often do not
# work properly. You can run this script periodically in order to
# access your shares at regular intervals and prevent this kind of disconnections.
#
# I haven't needed this script for a while now, but I kept it just in case.
#
# You will have to manually edit this script in order to specify your mountpoints,
# see ALL_MOUNTPOINTS below.
#
# In order to schedule this script to run periodically, edit your cron table
# with command "crontab -e", and add a line like this for a 5-minute interval:
#
#   */5 * * * * "$HOME/path/to/your/keep-windows-shares-alive.sh" >"/tmp/$LOGNAME-keep-windows-shares-alive.log"  2>&1
#
# Inspect the log file at least once to verify that the script is working properly
# when started by cron.
#
# cron has the habit of e-mailing the user any text that the command outputs. You may only realise
# when you install an e-mail server on the system, perhaps inadvertently as a prerequisite of some other software.
# Or you may not notice at all, but the local mail directory for root or your user may just keep forever growing.
# Therefore, after verifying that the command is working as intended, you may want to append >/dev/null
# to the cron command, or to drop only all stdout but let stderr through.

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


printf "Script $0 started at %(%Y-%m-%d %H:%M:%S)T.\\n"

declare -a START_TIME="$SECONDS"

declare -a ALL_MOUNTPOINTS

# Specify your own mountpoins here:
ALL_MOUNTPOINTS+=("$HOME/WindowsShares/MyMountpoint1")
ALL_MOUNTPOINTS+=("$HOME/WindowsShares/MyMountpoint2")


declare -i ALL_MOUNTPOINTS_ELEM_COUNT="${#ALL_MOUNTPOINTS[@]}"

declare -r SHOW_DIR_CONTENTS=true

for ((i=0; i<ALL_MOUNTPOINTS_ELEM_COUNT; i+=1)); do

  MOUNTPOINT="${ALL_MOUNTPOINTS[$i]}"

  echo "Scanning mount point: $MOUNTPOINT"

  if $SHOW_DIR_CONTENTS; then
    ls -la -- "$MOUNTPOINT"
    echo
  else
    ls -- "$MOUNTPOINT"  >/dev/null
  fi

done

printf "All mountpoints done in %s seconds.\\n" $(( SECONDS - START_TIME ))
