#!/bin/bash

# backup.sh version 1.04
#
# This is the script template I normally use to back up my files under Linux.
#
# Before running this script, copy it somewhere else and edit the directory paths
# to backup and the subdirectories and file extensions to exclude. The resulting
# backup files will be placed in the current (initially empty) directory.
#
# If you are backing up to an external disk, beware that the compressed files will be
# read back in order to create the redundancy data. If the external disk is slow,
# it may take a long time. Therefore, you may want to create the backup files on your
# primary disk first and move the resulting files to the external disk afterwards.
#
# It is probably most convenient to run this script with "background.sh", so that
# you get a visual notification at the end.
#
# Before you start your backup, remember to close any process that may be using
# the files you are backing up. For example, if you are backing up your Thunderbird
# mailbox, you should close Thunderbird first, or you will risk mailbox corruption
# on your backup copy.
#
# If the backup takes a long time, you may want to temporarily reconfigure your
# system's power settings so as to prevent your computer from going to sleep
# while backing up.
#
# About the par2 tool that creates the redundancy information:
#   Ubuntu/Debian Linux comes with an old 'par2' tool (as of oct 2017), which is
#   very slow and single-threaded. It is best to use version 0.7.4 or newer.
#
# Copyright (c) 2015-2017 R. Diez
# Licensed under the GNU Affero General Public License version 3.

set -o errexit
set -o nounset
set -o pipefail


# If you are using encrypted home folders on a CPU without hardware-accelerated encryption,
# it is faster to place your backup outside your home directory. But you should
# only do that if your backup is encrypted itselt (see SHOULD_ENCRYPT below).
BASE_DEST_DIR="."
pushd "$BASE_DEST_DIR" >/dev/null

TARBALL_BASE_FILENAME="MyBackupFiles-$(date "+%F")"

# When testing this script, you may want to temporarily turn off compression and encryption,
# especially if your CPU is very slow.
SHOULD_COMPRESS=true
SHOULD_ENCRYPT=true
SHOULD_GENERATE_REDUNDANT_DATA=true

FILE_SPLIT_SIZE="2g"
REDUNDANCY_PERCENTAGE="1"

# You will normally want to test the data after you have moved it to the external backup disk.
TEST_TARBALLS=false
TEST_REDUDANT_DATA=false

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

if $SHOULD_GENERATE_REDUNDANT_DATA; then
  if ! type "$TOOL_PAR2" >/dev/null 2>&1 ;
  then
    abort "The '$TOOL_PAR2' tool is not installed. See the comments in this script for a possibly faster alternative."
  fi
fi


SHOULD_ASK_FOR_CONFIRMATION=true

if $SHOULD_ASK_FOR_CONFIRMATION; then

  REMINDERS_FOR_USER=""

  # You will need to amend the text below to suit your needs.
  REMINDERS_FOR_USER+="- Close your mail program (like Thunderbird, if you are backing it up)."
  REMINDERS_FOR_USER+=$'\n'
  REMINDERS_FOR_USER+="- Close some other program whose files you are backing up."
  REMINDERS_FOR_USER+=$'\n'
  REMINDERS_FOR_USER+="- Mount the network drive (if necessary)."
  REMINDERS_FOR_USER+=$'\n'
  REMINDERS_FOR_USER+="- Etc."

  if false; then

    # Ask for confirmation with GUI tool Zenity.
    # The trouble is, 7z will ask afterwards for the password in the terminal window.

    ZENITY_TOOL="zenity"
    command -v "$ZENITY_TOOL" >/dev/null 2>&1  ||  abort "Tool '$ZENITY_TOOL' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu the associated package is called \"zenity\"."

    set +o errexit
    # Unfortunately, there is no way to set the cancel button to be the default.
    "$ZENITY_TOOL" --question --title "Please confirm"  --text "$REMINDERS_FOR_USER" --ok-label "Start backup"  --cancel-label "Cancel"
    ZENITY_EXIT_CODE="$?"
    set -o errexit

    case "$ZENITY_EXIT_CODE" in
      0) : ;;
      1) abort "User cancelled.";;
      *) abort "Unexpected exit code from \"$ZENITY_TOOL\"." ;;
    esac

  else

    # Ask for confirmation in the text console.

    REMINDERS_FOR_USER+=$'\n'
    REMINDERS_FOR_USER+="Please press Enter to continue: "

    read -r -p "$REMINDERS_FOR_USER" LINE_READ_TO_DISCARD
    printf "\\n"

  fi

fi


# If you happen to be working near midnight, even with the automatic file deletion
# you could end up with 2 sets of backup files, yesterday's and today's. Therefore,
# it is best to create a separate subdirectory for the archive files.
# This way, the user will hopefully realise that in that particular case
# there are 2 directories with different dates.
mkdir -p -- "$TARBALL_BASE_FILENAME"
pushd "$TARBALL_BASE_FILENAME" >/dev/null

# Delete any previous backup files, which is convenient if you modify and re-run this script.
rm -fv -- "$TARBALL_BASE_FILENAME"*  # The tarball gets splitted into files with extensions like ".001".
                                     # There are also ".par2" files to delete.

TARBALL_FILENAME="$TARBALL_BASE_FILENAME.7z"

# Missing features in 7z:
# - Suppress printing all filenames as they are compressed.
# - Do not attempt to compress incompressible files, like JPEG pictures.
# - No multithreading support for the 'deflate' (zip) compression method (as of January 2016,
#   7z version 15.14) for the .7z file format (although it looks like it is supported for the .zip file format).
#   Method 'LZMA2' does support multithreading, but it is much slower overall, and apparently
#   achieves little more compression on the fastest mode, at least on my files.
# - Recovery records (redundant information in case of small file corruption).
#   This is why we create recovery records afterwards with tool 'par2'.
# - Cannot update split archives. If we want to compress different files with different settings,
#   we have to keep different archives.
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

if $SHOULD_COMPRESS; then
  # -mx1 : Value 1 is 'fastest' compression method.
  COMPRESSION_OPTIONS="-m0=Deflate -mx1"
else
  # With options "-m0=Deflate -mx0", 7z still tries to compress. Therefore, switch to the "Copy" method.
  COMPRESSION_OPTIONS="-m0=Copy"
fi

if $SHOULD_ENCRYPT; then
  ENCRYPTION_OPTIONS="-p"
else
  ENCRYPTION_OPTIONS=""
fi


echo "Compressing files..."

# 7z options below:
#   -mmt : Turn on multithreading support (which is actually not supported for the 'deflate' method
#          for the .7z file format, see comments above).
#   -ms  : Turn on solid mode, which should improve the compression ratio.
#   -mhe=on : Enables archive header encryption (encrypt filenames).
#   -ssc- : turn off case sensitivity, so that *.jpg matches both ".jpg" and ".JPG".

# When 7z cannot find some of the files to back up, it issues a warning and carries on.
# However, we want to make it clear that the backup process did not actually complete successfully,
# because some files are missing.
# Therefore, we capture the exit code and print a "failed" message at the bottom, so that it is
# obvious that it failed.
set +o errexit

"$TOOL_7Z" a -t7z "$TARBALL_FILENAME" $COMPRESSION_OPTIONS -mmt -ms -mhe=on -ssc- -v$FILE_SPLIT_SIZE  $ENCRYPTION_OPTIONS \
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
    -- \
    \
    "$HOME/dirToBackup1" \
    "$HOME/dirToBackup2"

# You will probably want to backup the following easy-to-forget directories:
#   "$HOME/.ssh"         (your SSH encryption keys)
#   "$HOME/.thunderbird" (your Thunderbird mailbox)
#   "$HOME/.bashrc"      (your bash init script)
#   This backup script.


EXIT_CODE="$?"
set -o errexit

if [ $EXIT_CODE -ne 0 ]; then
  abort "Backup command failed."
fi


if $SHOULD_GENERATE_REDUNDANT_DATA; then
  echo "Building redundant records..."

  MEMORY_OPTION="" # The default memory limit for the standard 'par2' is 16 MiB. I have been thinking about giving it 512 MiB
                   # with option "-m512", but it does not seem to matter much for performance purposes, at least with
                   # the limited testing that I have done.

  # Note that the PAR2 files do not have ".7z" in their names, in order to
  # prevent any possible confusion. Otherwise, a wildcard glob like "*.7z.*" when
  # building the PAR2 files might include any existing PAR2 files again,
  # which is a kind of recursion to avoid.

  "$TOOL_PAR2" create -q -r$REDUNDANCY_PERCENTAGE $MEMORY_OPTION -- "$TARBALL_BASE_FILENAME.par2" "$TARBALL_FILENAME."*
fi

# If you are thinking about compressing the .par2 files, I have verified empirically
# that they do not compress at all. After all, they are derived from compressed,
# encrypted files.

TEST_TARBALL_CMD="\"$TOOL_7Z\" t -- \"$TARBALL_FILENAME\".001"

if $TEST_TARBALLS; then
  echo "Testing the compressed files..."
  eval "$TEST_TARBALL_CMD"
fi

if $SHOULD_GENERATE_REDUNDANT_DATA; then
  VERIFY_PAR2_CMD="\"$TOOL_PAR2\" verify -q -- \"$TARBALL_BASE_FILENAME.par2\""

  if $TEST_REDUDANT_DATA; then
    echo "Verifying the redundant records..."
    eval "$VERIFY_PAR2_CMD"
  fi
fi


echo
echo "Generating the test script..."
TEST_SCRIPT_FILENAME="test-backup-integrity.sh"

{
  echo "#!/bin/bash"
  echo ""
  echo "set -o errexit"
  echo "set -o nounset"
  echo "set -o pipefail"
  echo ""

  echo "echo \"Testing the compressed files...\""
  echo "$TEST_TARBALL_CMD"
} >"$TEST_SCRIPT_FILENAME"


if $SHOULD_GENERATE_REDUNDANT_DATA; then
  {
    echo ""
    echo "echo"
    echo "echo \"Verifying the redundant records...\""
    echo "$VERIFY_PAR2_CMD"
  } >>"$TEST_SCRIPT_FILENAME"

fi

{
  echo ""
  echo "echo"
  echo "echo \"Finished testing the backup integrity, everything OK.\""
} >>"$TEST_SCRIPT_FILENAME"

chmod a+x -- "$TEST_SCRIPT_FILENAME"

echo
echo "Finished creating backup files."
echo "If you need to copy the files to external storage, consider using script 'copy-with-rsync.sh'."
echo "You should test the compressed files on their final backup location with the generated '$TEST_SCRIPT_FILENAME' script."

popd >/dev/null
popd >/dev/null
