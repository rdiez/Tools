#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}


# I normally have environment variable MY_TOOLS_DIR defined.
# If not, assume that RotateDir.pl and BackupWikiPages.sh are nearby.

if is_var_set "MY_TOOLS_DIR"; then
  PATH_TO_ROTATE_DIR_TOOL="$MY_TOOLS_DIR/RotateDir/RotateDir.pl"
  PATH_TO_BACKUP_SCRIPT="$MY_TOOLS_DIR/BackupWikiPages/BackupWikiPages.sh"
else
  PATH_TO_ROTATE_DIR_TOOL="../RotateDir/RotateDir.pl"
  PATH_TO_BACKUP_SCRIPT="./BackupWikiPages.sh"
fi

SUBDIR_NAME="WikiPagesBackup"

mkdir --parents -- "$SUBDIR_NAME"

echo "Rotating backup directory..."

NEXT_DIR_NAME="$("$PATH_TO_ROTATE_DIR_TOOL" --slot-count 15 --dir-name-prefix "Backup-" --dir-naming-scheme date --output-only-new-dir-name -- "$SUBDIR_NAME")"

"$PATH_TO_BACKUP_SCRIPT"  "$NEXT_DIR_NAME"
