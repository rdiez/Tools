#!/bin/bash

# backup.sh script template version 2.17
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
# Instead of using 7z, this script could run a pipe like this:
#   tar -> encrypt -> pv -> file split
# The 'pv' command could then show how fast data is being backed up.
#
# About the par2 tool that creates the redundancy information:
#   Ubuntu/Debian Linux comes with an old 'par2' tool (as of oct 2017), which is
#   very slow and single-threaded. It is best to use version 0.7.4 or newer.
#
# Copyright (c) 2015-2019 R. Diez
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
REDUNDANT_DATA_REGENERATION_SCRIPT_FILENAME="regenerate-par2-redundant-data.sh"

SHOULD_DISPLAY_REMINDERS=true

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
# but that is not recommended, because the system's disk cache may falsify the result.
SHOULD_TEST_TARBALLS=false
SHOULD_TEST_REDUNDANT_DATA=false

# Try not to specify below the full path to these tools, but just their short filenames.
# If they live on non-standard locatios, add those to the PATH before running this script.
# The reason is that these tool names end up in the generated test script on the backup destination,
# and the computer running the test script later on may have these tools in a different location.
declare -r TOOL_7Z="7z"
declare -r TOOL_PAR2="par2"
declare -r TOOL_ZENITY="zenity"
declare -r TOOL_YAD="yad"
declare -r TOOL_NOTIFY_SEND="notify-send"

# Zenity has window size issues with GTK 3 and has become unusable lately.
# Therefore, YAD is recommended instead.
declare -r DIALOG_METHOD="yad"

declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit "$EXIT_CODE_ERROR"
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


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


display_confirmation_zenity ()
{
  local MSG="$1"

  # Unfortunately, there is no way to set the cancel button to be the default.
  local CMD
  printf -v CMD  "%q --no-markup  --question --title %q  --text %q  --ok-label \"Start backup\"  --cancel-label \"Cancel\""  "$TOOL_ZENITY"  "Backup Confirmation"  "$MSG"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1) echo
       echo "The user cancelled the backup."
       exit "$EXIT_CODE_SUCCESS";;
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_ZENITY\"." ;;
  esac
}


display_reminder_zenity ()
{
  local MSG="$1"

  local CMD
  printf -v CMD  "%q --no-markup  --info  --title %q  --text %q"  "$TOOL_ZENITY"  "Backup Reminder"  "$MSG"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1) : ;;  # If the user presses the ESC key, or closes the window, Zenity yields an exit code of 1.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_ZENITY\"." ;;
  esac
}


display_confirmation_yad ()
{
  local MSG="$1"

  # Unfortunately, there is no way to set the cancel button to be the default.
  # Option --fixed is a work-around to excessively tall windows with YAD version 0.38.2 (GTK+ 3.22.30).
  local CMD
  printf -v CMD \
         "%q --fixed --no-markup  --image dialog-question --title %q  --text %q  --button=%q:0  --button=gtk-cancel:1" \
         "$TOOL_YAD" \
         "Backup Confirmation" \
         "$MSG" \
         "Start backup!gtk-ok"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1|252)  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
       echo
       echo "The user cancelled the backup."
       exit "$EXIT_CODE_SUCCESS";;
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


display_reminder_yad ()
{
  local MSG="$1"

  # Option --fixed is a work-around to excessively tall windows with YAD version 0.38.2 (GTK+ 3.22.30).
  local CMD
  printf -v CMD \
         "%q --fixed --no-markup  --image dialog-information  --title %q  --text %q --button=gtk-ok:0" \
         "$TOOL_YAD" \
         "Backup Reminder" \
         "$MSG"

  echo "$CMD"

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0|252) : ;;  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


display_confirmation ()
{
  case "$DIALOG_METHOD" in
    zenity)  display_confirmation_zenity "$@";;
    yad)     display_confirmation_yad "$@";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac
}

display_reminder ()
{
  case "$DIALOG_METHOD" in
    zenity)  display_reminder_zenity "$@";;
    yad)     display_reminder_yad "$@";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac
}


display_desktop_notification ()
{
  local TITLE="$1"
  local HAS_FAILED="$2"

  if command -v "$TOOL_NOTIFY_SEND" >/dev/null 2>&1; then

    if $HAS_FAILED; then
      "$TOOL_NOTIFY_SEND" --icon=dialog-error       -- "$TITLE"
    else
      "$TOOL_NOTIFY_SEND" --icon=dialog-information -- "$TITLE"
    fi

  else
    echo "Note: The '$TOOL_NOTIFY_SEND' tool is not installed, therefore no desktop pop-up notification will be issued. You may have to install this tool with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"libnotify-bin\"."
  fi
}


# ----------- Entry point -----------

verify_tool_is_installed  "$TOOL_7Z"  "p7zip-full"

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

# Unfortunately, the 7-Zip that ships with Ubuntu 18.04 is version 16.02, which is rather old,
# so you cannot use any fancy new options here.
#
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
#   "$HOME/Desktop"      (your desktop icons and files)
#   This backup script itself.

add_pattern_to_backup "$HOME/MyDirectoryToBackup1"
add_pattern_to_backup "$HOME/MyDirectoryToBackup2"

COMPRESS_CMD+=" && popd >/dev/null"


if $SHOULD_DISPLAY_REMINDERS; then

  case "$DIALOG_METHOD" in
    zenity)  verify_tool_is_installed  "$TOOL_ZENITY"  "zenity";;
    yad)     verify_tool_is_installed  "$TOOL_YAD"     "yad";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac

  BEGIN_REMINDERS="The backup is about to begin:"$'\n'

  BEGIN_REMINDERS+="- Mount the external disk."$'\n'
  BEGIN_REMINDERS+="- Set the system power settings to prevent your computer from going to sleep during the backup."$'\n'
  BEGIN_REMINDERS+="- Close Thunderbird."$'\n'
  BEGIN_REMINDERS+="- Close some other programs you often run that use files being backed up."$'\n'
  BEGIN_REMINDERS+="- Place other reminders of yours here."
  # Note that there is no end-of-line character (\n) at the end of the last line.

  display_confirmation "$BEGIN_REMINDERS"

fi


echo "Backing up files..."

read_uptime_as_integer
declare -r BACKUP_START_UPTIME="$UPTIME"

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

read_uptime_as_integer
declare -r BACKUP_FINISH_UPTIME="$UPTIME"
declare -r BACKUP_ELAPSED_SECONDS="$((BACKUP_FINISH_UPTIME - BACKUP_START_UPTIME))"
get_human_friendly_elapsed_time "$BACKUP_ELAPSED_SECONDS"
echo "Elapsed time backing up files: $ELAPSED_TIME_STR"


pushd "$DEST_DIR" >/dev/null

# Unfortunately, par2cmdline as of version 0.8.0 provides no useful progress indication.
# I have reported this as an issue here:
#   Provide some sort of progress indication
#   https://github.com/Parchive/par2cmdline/issues/124

MEMORY_OPTION="" # The default memory limit for the standard 'par2' is 16 MiB. I have been thinking about giving it 512 MiB
                 # with option "-m512", but it does not seem to matter much for performance purposes, at least with
                 # the limited testing that I have done.

printf -v GENERATE_REDUNDANT_DATA_CMD  "%q create -q -r$REDUNDANCY_PERCENTAGE $MEMORY_OPTION -- %q %q.*"  "$TOOL_PAR2"  "$TARBALL_BASE_FILENAME.par2"  "$TARBALL_BASE_FILENAME.7z"

# If you are thinking about compressing the .par2 files, I have verified empirically
# that they do not compress at all. After all, they are derived from compressed,
# encrypted files.

printf -v TEST_TARBALL_CMD  "%q t -- %q"  "$TOOL_7Z"  "$TARBALL_BASE_FILENAME.7z.001"

printf -v VERIFY_PAR2_CMD  "%q verify -q -- %q"  "$TOOL_PAR2"  "$TARBALL_BASE_FILENAME.par2"

printf -v DELETE_PAR2_FILES_CMD  "rm -fv -- %q*.par2"  "$TARBALL_BASE_FILENAME"


# Generate the scripts before generating the redundant data. This way,
# if the process fails, the user can manually run the generated scripts
# to complete the missing steps.

echo
echo "Generating the test and par2 regeneration scripts..."

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


{
  echo "#!/bin/bash"
  echo ""
  echo "set -o errexit"
  echo "set -o nounset"
  echo "set -o pipefail"
  echo ""

  echo "# Delete any existing redundancy data files first."
  echo "$DELETE_PAR2_FILES_CMD"
  echo "echo"
  echo ""

  echo "echo \"Regenerating the par2 redundant data...\""
  echo "$GENERATE_REDUNDANT_DATA_CMD"

  echo ""
  echo "echo"
  echo "echo \"Finished regenerating the par2 redundant data.\""
} >"$REDUNDANT_DATA_REGENERATION_SCRIPT_FILENAME"

chmod a+x -- "$REDUNDANT_DATA_REGENERATION_SCRIPT_FILENAME"


if $SHOULD_GENERATE_REDUNDANT_DATA; then
  echo "Building redundant records..."

  read_uptime_as_integer
  declare -r REDUNDANT_DATA_START_UPTIME="$UPTIME"

  # Note that the PAR2 files do not have ".7z" in their names, in order to
  # prevent any possible confusion. Otherwise, a wildcard glob like "*.7z.*" when
  # building the PAR2 files might include any existing PAR2 files again,
  # which is a kind of recursion to avoid.

  echo "$GENERATE_REDUNDANT_DATA_CMD"
  eval "$GENERATE_REDUNDANT_DATA_CMD"

  read_uptime_as_integer
  declare -r REDUNDANT_DATA_FINISH_UPTIME="$UPTIME"
  declare -r REDUNDANT_DATA_ELAPSED_SECONDS="$((REDUNDANT_DATA_FINISH_UPTIME - REDUNDANT_DATA_START_UPTIME))"
  get_human_friendly_elapsed_time "$REDUNDANT_DATA_ELAPSED_SECONDS"
  echo "Elapsed time building the redundant records: $ELAPSED_TIME_STR"
fi


if $SHOULD_TEST_TARBALLS; then
  echo "Testing the compressed files..."
  echo "$TEST_TARBALL_CMD"
  eval "$TEST_TARBALL_CMD"
fi


if $SHOULD_GENERATE_REDUNDANT_DATA; then
  if $SHOULD_TEST_REDUNDANT_DATA; then
    echo "Verifying the redundant records..."
    echo "$VERIFY_PAR2_CMD"
    eval "$VERIFY_PAR2_CMD"
  fi
fi

popd >/dev/null


BACKUP_DU_OUTPUT="$(du  --bytes  --human-readable  --summarize  --si "$DEST_DIR")"
# The first component is the data size. The second component is the directory name, which we discard.
read -r BACKUP_SIZE _ <<<"$BACKUP_DU_OUTPUT"


# The backup can write large amounts of data to an external USB disk.
# I think it is a good idea to ensure that the whole write-back cache
# has actually been written to disk before declaring the backup complete.
# It would be best to just sync the filesystem we are writing to,
# or even just the backup files that have just been generated,
# but I do not know whether such a selective 'sync' is possible.
echo
echo "Flushing the write-back cache..."
sync


if $SHOULD_DISPLAY_REMINDERS; then

  display_desktop_notification "The backup process has finished" false

  END_REMINDERS="The backup process has finished:"$'\n'

  END_REMINDERS+="- Unmount the external disk."$'\n'
  END_REMINDERS+="- Restore the normal system power settings."$'\n'
  END_REMINDERS+="- Re-open Thunderbird."$'\n'
  END_REMINDERS+="- Place other reminders of yours here."$'\n'
  END_REMINDERS+="- If you need to copy the files to external storage, consider using"$'\n'
  END_REMINDERS+="   script 'copy-with-rsync.sh'."$'\n'
  END_REMINDERS+="- You should test the compressed files on their final backup location with"$'\n'
  END_REMINDERS+="   the generated '$TEST_SCRIPT_FILENAME' script."$'\n'
  END_REMINDERS+="   Before testing, unmount and remount the disk. Otherwise,"$'\n'
  END_REMINDERS+="   the system's disk cache may falsify the result."
  # Note that there is no end-of-line character (\n) at the end of the last line.

  display_reminder "$END_REMINDERS"

fi

echo
echo "Finished creating backup files."
echo "Total backup size: $BACKUP_SIZE"
echo "If you need to copy the files to external storage, consider using script 'copy-with-rsync.sh'."
echo "You should test the compressed files on their final backup location with the generated '$TEST_SCRIPT_FILENAME' script."
