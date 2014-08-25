#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Rotating backup directory..."

PATH_TO_ROTATE_DIR_TOOL="../RotateDir/RotateDir.pl"

SUBDIR_NAME="WikiPagesBackup"

mkdir -p "$SUBDIR_NAME"

NEXT_DIR_NAME="$("$PATH_TO_ROTATE_DIR_TOOL" --slot-count 15 --dir-name-prefix "Backup-" --dir-naming-scheme date --output-only-new-dir-name "$SUBDIR_NAME")"

./BackupWikiPages.sh "$NEXT_DIR_NAME" 
