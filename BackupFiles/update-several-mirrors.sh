#!/bin/bash

# This example scripts calls update-backup-mirror-by-modification-time.sh twice
# with a single background.sh invocation in order to display just one
# "has finished" visual notification at the end of the long backup process.
#
# Copyright (c) 2015 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


AddBackupSrcDest ()
{
  local SRC
  local DEST

  printf -v SRC  "%q" "$1"
  printf -v DEST "%q" "$2"

  CMD+=" && ./update-backup-mirror-by-modification-time.sh  $SRC  $DEST"
}


# Starts tool 'meld' to manually verify all backup contents in $DEST1.

StartMeld ()
{
  local SRC
  local DEST
  local MELD_CMD

  printf -v SRC  "%q" "$1"
  printf -v DEST "%q" "$2"

  MELD_CMD="meld  $SRC  $DEST  &"
  echo "$MELD_CMD"
  eval "$MELD_CMD"
}


SRC1="$HOME/src/src1"
DEST1="$HOME/dest/dest1"

SRC2="$HOME/src/src2"
DEST2="$HOME/dest/dest2"


# The backup process.
if true; then
  CMD="true"  # Starting the command with "true" allows you to stop worrying about adding the "&&" suffix before or after each command.

  AddBackupSrcDest "$SRC1" "$DEST1"
  AddBackupSrcDest "$SRC2" "$DEST2"

  printf -v CMD_QUOTED "%q" "$CMD"

  EVAL_CMD="background.sh bash -c $CMD_QUOTED"

  echo "$EVAL_CMD"
  eval "$EVAL_CMD"
fi


# Uncomment in order to manually verify the backups:
#   StartMeld "$SRC1" "$DEST1"
#   StartMeld "$SRC2" "$DEST2"
