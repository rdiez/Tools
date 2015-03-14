#!/bin/bash

# This is the script template I normally use to back up my files under Linux.
#
# It is probably most convenient to run this script with "background.sh".
#
# Copyright (c) 2015 R. Diez
# Licensed under the GNU Affero General Public License version 3.

set -o errexit
set -o nounset
set -o pipefail


TARBALL_BASE_FILENAME="MyBackupFiles-$(date "+%F")"

TOOL_7Z="7z"
TOOL_PAR2="par2"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


if ! type "$TOOL_7Z" >/dev/null 2>&1 ;
then
  abort "The '$TOOL_7Z' tool is not installed."
fi

if ! type "$TOOL_PAR2" >/dev/null 2>&1 ;
then
  abort "The '$TOOL_PAR2' tool is not installed."
fi


# Delete any previous backup files, which is convenient if you modify and re-run this script.
# Only today's files are automatically deleted, therefore, if you happen to be working
# near midnight, you may end up having to manually delete yesterday's files.
rm -fv "$TARBALL_BASE_FILENAME"*  # The tarball gets splitted into files with extensions like ".001".
                                  # There are also ".par2" files to delete.

TARBALL_FILENAME="$TARBALL_BASE_FILENAME.7z"

# Missing features in 7z:
# - Suppress printing all filenames as they are compressed.
# - Do not attempt to compress incompressible files, like JPEG pictures.
# - No multithreading support for the deflate (zip) compression method (as of february 2015).
#   Method 'LZMA2' does support multithreading, but it is much slower overall, and apparently
#   achieves little more compression on the fastest mode.
# - Recovery records (redundant information in case of small file corruption).
#   This is why we create recovery records afterwards with tool 'par2'.
#
# Avoid using 7z's command-line option '-r'. According to the man page:
# "CAUTION: this flag does not do what you think, avoid using it"
#
# 7z exclusion syntax examples:
#
#   - Exclude a particular subdirectory:
#     -x!dir1/subdir1
#
#     Note that "dir1" must be at the backup's root directory.
#
#   - Exclude all "Tmp" subdirs:
#     -xr!Tmp
#
#   - Exclude all *.bak files (by extension):
#     -xr!*.bak
#
# When testing this script, you may want to replace switch -mx1 with -mx0 (no compression, much faster).
# You may also want to temporarily remove the -p (password) switch.

# When 7z cannot find some of the files to back up, it issues a warning.
# However, we want to make it clear that the backup process did not complete successfully.
set +o errexit

"$TOOL_7Z" a -t7z "$TARBALL_FILENAME" -m0=Deflate -mx1 -mmt -ms -mhe=on -v2g -p \
    \
    '-x!dirToBackup1/skipThisParticularDir/Subdir1' \
    '-x!dirToBackup1/skipThisParticularDir/Subdir2' \
    \
    '-xr!skipAllSubdirsWithThisName1' \
    '-xr!skipAllSubdirsWithThisName2' \
    \
    '-xr!*.skipAllFilesWithThisExtension1' \
    '-xr!*.skipAllFilesWithThisExtension2' \
    \
    "$HOME/dirToBackup1" \
    "$HOME/dirToBackup2"

EXIT_CODE="$?"
set -o errexit

if [ $EXIT_CODE -ne 0 ]; then
  abort "Backup command failed."
fi


echo "Building redundant records..."
REDUNDANCY_PERCENTAGE="1"
"$TOOL_PAR2" create -q -r$REDUNDANCY_PERCENTAGE "$TARBALL_FILENAME.par2" "$TARBALL_FILENAME."*

# If you are thinking about compressing the .par2 files, I have verified empirically
# that they do not compress at all. After all, they are derived from compressed,
# encrypted files.

echo "Finished creating backup."

TEST_TARBALL_CMD="\"$TOOL_7Z\" t \"$TARBALL_FILENAME\".001"

echo "- If you need to copy the files to external storage, consider using script 'copy-with-rsync.sh'."

if true; then
  echo "- You should test the compressed files with:"
  echo "  $TEST_TARBALL_CMD"
else
  echo "Testing the compressed files..."
  eval "$TEST_TARBALL_CMD"
fi


VERIFY_PAR2_CMD="\"$TOOL_PAR2\" verify -q \"$TARBALL_FILENAME.par2\""

if true; then
  echo "- You should verify the redundant records with:"
  echo " $VERIFY_PAR2_CMD"
else
  echo "Verifying redundant records..."
  "$TOOL_PAR2" verify -q "$TARBALL_FILENAME.par2"
fi
