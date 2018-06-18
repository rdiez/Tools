#!/bin/bash

# backup.sh script template version 2.02
#
# This is the script template I normally use to back up my files under Linux.
#
# Before running this script, copy it somewhere else and edit the directory paths
# to backup, the subdirectories and file extensions to exclude, and the
# destination directory.
#
# If you are backing up to an external disk, beware that the compressed files will be
# read back in order to create the redundancy data. If the external disk is slow,
# it may take a long time. Therefore, assuming that you have enough space,
# you may want to create the backup files on your internal disk first and
# move the resulting files to the external disk afterwards.
#
# If you are using encrypted home folders on a CPU without hardware-accelerated encryption,
# it is faster to place your backup outside your home directory. But you should
# only do that if your backup is encrypted itself (see SHOULD_ENCRYPT below).
#
# It is probably most convenient to run this script with "background.sh", so that
# it runs with low priority and you get a visual notification when finished.
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
# At the end, you can inspect the tarballs in order to check whether too many files
# got backed up. Just open the first .7z.001 file with the GNOME Archive Manager (file-roller)
# or a similar tool. Alternatively, a plain text list of files may be better suited
# for the task. You can generate a text file list with this command:
#   7z l *.7z.001 >"list-unsorted.txt" && sed 's/^.\{53\}//' "list-unsorted.txt" | sort - >"list.txt"
# The first part generates a temporary list. The 'sed' command cuts the first columns to leave just
# the file paths, and the 'sort' command sorts the list, because 7z reorders the files
# to achieve a higher compression ratio.
# An possible improvement would be to implement a dry run mode in this script,
# maybe with 7z switch "-so >/dev/null", in order to generate the file list
# without actually generating the backup files.
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


# This script will create a subdirectory with all backup data under the following base directory:
BASE_DEST_DIR="."

# We need an absolute path in the rest of the script.
BASE_DEST_DIR="$(readlink --canonicalize --verbose -- "$BASE_DEST_DIR")"

TARBALL_BASE_FILENAME="BackupOfMyBigLaptop-$(date "+%F")"

TEST_SCRIPT_FILENAME="test-backup-integrity.sh"

# When testing this script, you may want to temporarily turn off compression and encryption,
# especially if your CPU is very slow.
SHOULD_COMPRESS=true
SHOULD_ENCRYPT=true
SHOULD_GENERATE_REDUNDANT_DATA=true

# Remember that some filesystems have limitations on the maximum file size.
# For example, the popular FAT32 can only handle files up to one byte less than 4gigabytes.
FILE_SPLIT_SIZE="2g"
REDUNDANCY_PERCENTAGE="1"

# You will normally want to test the data after you have moved it to the external backup disk,
# preferrably after disconnecting and reconnecting the disk.
# A script file is automatically generated on the destination directory for that purpose.
# With the following variables, you can also test the files right after finishing the backup,
# but that is not recommended, because the disk cache may falsify the result.
TEST_TARBALLS=false
TEST_REDUDANT_DATA=false

# Try not to specify below the full path to these tools, but just their short filenames.
# If they live on non-standard locatios, add those to the PATH before running this script.
# The reason is that these tool names end up in the generated test script on the backup destination,
# and the computer running the test script later on may have these tools in a different location.
TOOL_7Z="7z"
TOOL_PAR2="par2"

declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


str_starts_with ()
{
  # $1 = string
  # $2 = prefix

  # From the bash manual, "Compound Commands" section, "[[ expression ]]" subsection:
  #   "Any part of the pattern may be quoted to force the quoted portion to be matched as a string."
  # Also, from the "Pattern Matching" section:
  #   "The special pattern characters must be quoted if they are to be matched literally."

  if [[ $1 == "$2"* ]]; then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


does_pattern_match_at_least_one_existing_file_or_directory ()
{
  local PATTERN="$1"

  # If 'find' does not find the base $(dirname), it will generate a short error message.
  # However, we want to generate a better error message ourselves.
  # So check upfront whether the base directory exists.
  if [[ ! -e "$(dirname "$PATTERN")" ]]; then
    return $BOOLEAN_FALSE
  fi

  local FIND_CMD
  printf  -v FIND_CMD  "find %q -maxdepth 1 -name %q -print -quit"  "$(dirname "$PATTERN")"  "$(basename "$PATTERN")"

  local FIRST_FILENAME_FOUND
  FIRST_FILENAME_FOUND="$(eval "$FIND_CMD")"

  if [[ -z $FIRST_FILENAME_FOUND ]]; then
    return $BOOLEAN_FALSE
  fi

  return $BOOLEAN_TRUE
}


add_pattern_to_backup ()
{
  local PATTERN="$1"

  if ! str_starts_with "$PATTERN" "/"; then
    abort "Pattern to back up \"$PATTERN\" does not start with a leading slash ('/')."
  fi


  # 7z does not error if a given path is not found, so we need to check manually here.

  if ! does_pattern_match_at_least_one_existing_file_or_directory "$PATTERN"; then
    abort "Pattern to back up \"$PATTERN\" does not match any existing file or directory names."
  fi


  # Remove the leading slash ('/').
  PATTERN="${PATTERN:1}"

  local QUOTED_PATH
  printf  -v QUOTED_PATH  "%q"  "$PATTERN"
  COMPRESS_CMD+=" $QUOTED_PATH"
}


add_pattern_to_exclude ()
{
  local PATTERN="$1"

  if ! str_starts_with "$PATTERN" "/"; then
    abort "Pattern to exclude \"$PATTERN\" does not start with a leading slash ('/')."
  fi


  # Check whether at least one file or directory matches the exclude pattern.
  # Otherwise, the user probably moved, renamed or deleted it, and forgot to update this script.
  #
  # The current implementation only allows for wildcards to be in the last path component.
  # But this is what we currently use.
  #
  # This check is not 100% correct, because 7z's pattern matching rules are probably not the same as in Bash,
  # but it should be enough for the kind of simple patterns we are using.

  if ! does_pattern_match_at_least_one_existing_file_or_directory "$PATTERN"; then
    abort "Pattern to exclude \"$PATTERN\" does not match any existing file or directory names."
  fi


  # Remove the leading slash ('/').
  PATTERN="${PATTERN:1}"

  local QUOTED_PATH
  printf  -v QUOTED_PATH  "%q"  "-x!$PATTERN"
  COMPRESS_CMD+=" $QUOTED_PATH"
}


# ----------- Entry point -----------

if ! type "$TOOL_7Z" >/dev/null 2>&1 ;
then
  abort "The '$TOOL_7Z' tool is not installed."
fi

if $SHOULD_GENERATE_REDUNDANT_DATA; then
  if ! type "$TOOL_PAR2" >/dev/null 2>&1 ;
  then
    abort "The '$TOOL_PAR2' tool is not installed. See the comments in this script for a possibly faster alternative version."
  fi
fi

DEST_DIR="$BASE_DEST_DIR/$TARBALL_BASE_FILENAME"

mkdir -p -- "$DEST_DIR"

# Delete any previous backup files, which is convenient if you modify and re-run this script.
#
# Note that the directory name contains the date. If you happen to be working near midnight
# and re-run this script, it may not delete the backup from a few minutes ago,
# so that you could end up with 2 sets of backup files, yesterday's and today's.
#
# Therefore, it is best to create a separate subdirectory for the archive files.
# This way, the user will hopefully realise that in that particular case near midnight
# there are 2 directories with different dates. Otherwise, the user may not immediately realise
# that all files are duplicated and the backup is twice the usual size.

rm -fv -- "$DEST_DIR/$TARBALL_BASE_FILENAME"*  # The tarball gets splitted into files with extensions like ".001".
                                               # There are also ".par2" files to delete.

if [ -f "$DEST_DIR/$TEST_SCRIPT_FILENAME" ]; then
  rm -fv -- "$DEST_DIR/$TEST_SCRIPT_FILENAME"
fi

TARBALL_FILENAME="$DEST_DIR/$TARBALL_BASE_FILENAME.7z"

# Missing features in 7z:
# - Suppress printing all filenames as they are compressed.
# - Do not attempt to compress incompressible files, like JPEG pictures.
#   You also cannot update split archives. If we want to compress different files
#   with different settings, we have to create different archives.
# - No multithreading support for the 'deflate' (zip) compression method (as of January 2016,
#   7z version 15.14) for the .7z file format (although it looks like it is supported for the .zip file format).
#   Method 'LZMA2' does support multithreading, but it is much slower overall, and apparently
#   achieves little more compression on the fastest mode, at least on my files.
# - Recovery records (redundant information in case of small file corruption).
#   This is why we create recovery records afterwards with tool 'par2'.
# - It is hard to make 7z store full pathnames. As a work-around, change to the root dir ('/'),
#   and then we manage to get the full path stored, except for the leading '/' in each path.
#   We need full paths. Otherwise, the exclude directories can be ambiguous if a name
#   exists in more than one directory to backup. Filenames inside the archive can also be ambiguous
#   if the full path is not included.
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


# Changing to the root directory allows us to store almost the full path of all files,
# see note above about 7z limitations in this respect for more information.
COMPRESS_CMD="pushd / >/dev/null"

printf  -v STR  "%q a -t7z %q"  "$TOOL_7Z"  "$TARBALL_FILENAME"
COMPRESS_CMD+=" && $STR"

if $SHOULD_COMPRESS; then
  # -mx1 : Value 1 is 'fastest' compression method.
  COMPRESS_CMD+=" -m0=Deflate -mx1"
else
  # With options "-m0=Deflate -mx0", 7z still tries to compress. Therefore, switch to the "Copy" method.
  COMPRESS_CMD+=" -m0=Copy"
fi

# 7z options below:
#   -mmt : Turn on multithreading support (which is actually not supported for the 'deflate' method
#          for the .7z file format, see comments above).
#   -ms  : Turn on solid mode, which should improve the compression ratio.
#   -mhe=on : Enables archive header encryption (encrypt filenames).
#   -ssc- : Turn off case sensitivity, so that *.jpg matches both ".jpg" and ".JPG".
#           That may yield problems if there are filenames that differ only in their uppper/lower cases.

COMPRESS_CMD+=" -mmt -ms -mhe=on -ssc-"

COMPRESS_CMD+=" -v$FILE_SPLIT_SIZE"

if $SHOULD_ENCRYPT; then
  COMPRESS_CMD+=" -p"
fi


add_pattern_to_exclude "$HOME/MyBigTempDir1"
add_pattern_to_exclude "$HOME/MyBigTempDir2"


# Exclude all subdirectories everywhere that are called "Tmp".
COMPRESS_CMD+=" '-xr!Tmp'"

COMPRESS_CMD+=" --"

# You will probably want to backup the following easy-to-forget directories:
#   "$HOME/.ssh"         (your SSH encryption keys)
#   "$HOME/.thunderbird" (your Thunderbird mailbox)
#   "$HOME/.bashrc"      (your bash init script)
#   This backup script itself.

add_pattern_to_backup "$HOME/MyDirectoryToBackup1"
add_pattern_to_backup "$HOME/MyDirectoryToBackup2"

COMPRESS_CMD+=" && popd >/dev/null"


echo "Compressing files..."

# When 7z cannot find some of the files to back up, it issues a warning and carries on.
# However, we want to make it clear that the backup process did not actually complete successfully,
# because some files are missing.
# Therefore, we capture the exit code and print a "failed" message at the bottom, so that it is
# obvious that it failed.
echo "$COMPRESS_CMD"
set +o errexit
eval "$COMPRESS_CMD"
EXIT_CODE="$?"
set -o errexit

if [ $EXIT_CODE -ne 0 ]; then
  abort "Backup command failed."
fi

pushd "$DEST_DIR" >/dev/null

MEMORY_OPTION="" # The default memory limit for the standard 'par2' is 16 MiB. I have been thinking about giving it 512 MiB
                 # with option "-m512", but it does not seem to matter much for performance purposes, at least with
                 # the limited testing that I have done.

printf -v GENERATE_REDUNDANT_DATA_CMD  "%q create -q -r$REDUNDANCY_PERCENTAGE $MEMORY_OPTION -- %q %q.*"  "$TOOL_PAR2"  "$TARBALL_BASE_FILENAME.par2"  "$TARBALL_BASE_FILENAME.7z"

if $SHOULD_GENERATE_REDUNDANT_DATA; then
  echo "Building redundant records..."

  # Note that the PAR2 files do not have ".7z" in their names, in order to
  # prevent any possible confusion. Otherwise, a wildcard glob like "*.7z.*" when
  # building the PAR2 files might include any existing PAR2 files again,
  # which is a kind of recursion to avoid.

  echo "$GENERATE_REDUNDANT_DATA_CMD"
  eval "$GENERATE_REDUNDANT_DATA_CMD"
fi

# If you are thinking about compressing the .par2 files, I have verified empirically
# that they do not compress at all. After all, they are derived from compressed,
# encrypted files.

printf -v TEST_TARBALL_CMD  "%q t -- %q"  "$TOOL_7Z"  "$TARBALL_BASE_FILENAME.7z.001"

if $TEST_TARBALLS; then
  echo "Testing the compressed files..."
  echo "$TEST_TARBALL_CMD"
  eval "$TEST_TARBALL_CMD"
fi

printf -v VERIFY_PAR2_CMD  "%q verify -q -- %q"  "$TOOL_PAR2"  "$TARBALL_BASE_FILENAME.par2"

if $SHOULD_GENERATE_REDUNDANT_DATA; then
  if $TEST_REDUDANT_DATA; then
    echo "Verifying the redundant records..."
    echo "$VERIFY_PAR2_CMD"
    eval "$VERIFY_PAR2_CMD"
  fi
fi


echo
echo "Generating the test script..."

{
  echo "#!/bin/bash"
  echo ""
  echo "set -o errexit"
  echo "set -o nounset"
  echo "set -o pipefail"
  echo ""

  # Normally, testing the redundant data would check the compressed files too.
  # But we need to test the compressed files at least once after the backup,
  # just in case the redundant files were created from already-corruput compressed files.

  echo "echo \"Testing the compressed files...\""
  echo "$TEST_TARBALL_CMD"

  echo ""
  echo "# In case you need to regenerate the redundant data, the command is:"
  echo "#   $GENERATE_REDUNDANT_DATA_CMD"

  echo ""
  echo "if $SHOULD_GENERATE_REDUNDANT_DATA; then"
  echo "  echo"
  echo "  echo \"Verifying the redundant records...\""
  echo "  $VERIFY_PAR2_CMD"
  echo "fi"

  echo ""
  echo "echo"
  echo "echo \"Finished testing the backup integrity, everything OK.\""
} >"$TEST_SCRIPT_FILENAME"

chmod a+x -- "$TEST_SCRIPT_FILENAME"

# The backup can write large amounts of data to an external USB disk.
# I think it is a good idea to ensure that the whole write-back cache
# has actually been written to disk before declaring the backup complete.
# It would be best to just sync the filesystem we are writing to,
# or even just the backup files that have just been generated,
# but I do not know whether such a selective 'sync' is possible.
echo "Flushing the write-back cache..."
sync

popd >/dev/null

echo
echo "Finished creating backup files."
echo "If you need to copy the files to external storage, consider using script 'copy-with-rsync.sh'."
echo "You should test the compressed files on their final backup location with the generated '$TEST_SCRIPT_FILENAME' script."
