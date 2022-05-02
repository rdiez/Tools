#!/bin/bash

# backup.sh script template version 2.31
#
# This is the script template I normally use to back up my files under Linux.
#
# It uses 7z to create compressed and encrypted backup files, and par2
# to generate extra redundant data for recovery purposes.
# Compression, encryption and redundant data are all optional and can be easily disabled.
# Scripts are automatically generated to test the backup and regenerate the redundant data later on.
#
# Incremental backups would be faster, but I would not always trust them. You tend to need special tools
# that are not available everywhere. It is hard to make sure that redundant data works well if the disk
# starts losing sectors. Also, renaming and moving files around can fool the logic that detects whether
# files have changed and need to be backed up again, unless you are using some advanced tool with deduplication.
#
# Before running this script, copy it somewhere else and edit:
# - The directory paths to backup (see add_pattern_to_backup).
# - The subdirectories and file extensions to exclude (see add_pattern_to_exclude).
# - The backup name (see BACKUP_NAME).
# - The destination directory (see BASE_DEST_DIR).
# - Optionally adjust PAR2_MEMORY_LIMIT_MIB and PAR2_PARALLEL_FILE_COUNT for performance.
# - Adjust DIALOG_METHOD for GUI or console notifications.
# - The reminders (see SHOULD_DISPLAY_REMINDERS, BEGIN_REMINDERS and END_REMINDERS).
#
# If you are backing up to a slow external disk, beware that the compressed files will be
# read back in order to create the redundant data. This is unfortunate. There is
# probably a better way to generate a compressed backup and its redundant data
# in a single operation, but I have not found a nice way to do it yet.
# It would be easier if the compressor supported redundant information directly.
#
# With the current implementation, if the external disk is slow, it may take a very long time,
# especially when generating the redundant data.
# Therefore, assuming that you have enough space, you may want to create the backup files on
# your (faster) internal disk first and move the resulting files to the external disk afterwards.
#
# Alternatively, it may be cheaper to buy an extra disk and make 2 copies of the
# backup data each time than to generate redundant data.
#
# You can also skip creation of the redundant data at first, and create it later on
# using another computer. A small script is generated and placed next to the backup files
# for that purpose.
#
# If you are using an encrypted disk home (like encrypted home folders on Linx)
# and you have a CPU without hardware-accelerated encryption,
# it is faster to place your backup somewhere that is not encrypted. But you should
# only do that if your backup is encrypted itself (see SHOULD_ENCRYPT below).
#
# It is probably most convenient to run this script with "background.sh", so that
# it runs with low priority and you get a visual or e-mail notification when finished.
# The optional memory limit below reduces the performance impact on other processes by preventing
# the backup operation from flushing the complete Linux filesystem cache. Beware to set it somewhat
# higher than par2's memory limit option -m . Verification does not need so much memory.
#
# The filter option prevents very long lines like "Loading: 4.2%^Moading: 7.5%^MLoading: 10.8%^MLoading: 14.1% [...]"
# from landing in the log file.
#
# Example commands:
#   export BACKGROUND_SH_LOW_PRIORITY_METHOD="systemd-run" && background.sh --memory-limit=$((4 * 1024))M --filter-log -- ./backup.sh
#   export BACKGROUND_SH_LOW_PRIORITY_METHOD="systemd-run" && background.sh --memory-limit=512M           --filter-log -- ./test-backup-integrity-first-time.sh
#
# Before you start your backup, remember to close any process that may be using
# the files you are backing up. For example, if you are backing up your Thunderbird
# mailbox, you should close Thunderbird first, or you will risk mailbox corruption
# on your backup copy. This script issues reminders before and after backing up,
# and you can edit them to mention such programs you normally run on your computer.
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
# A possible improvement would be to implement a dry run mode in this script,
# maybe with 7z switch "-so >/dev/null", in order to generate the file list
# without actually generating the backup files.
#
# Backup files should be verified on the destination disk, just in case.
# Small scripts are generated and placed next to the backup files for that purpose.
#
# The first time, verifying both the 7z and the par2 files gives more confidence,
# at the cost of reading the 7z data files twice. Otherwise, we would not realise that
# redundant information was perhaps built against a set of 7z files
# that was already corrupted during the first write.
# Again, if the compressor supported redundant data directly, the process
# would be much more efficient.
#
# Verifying your backups again at a later point in time helps detect whether the disk
# is degrading during storage. In this case, it is only worth verifying the par2 files,
# because both par2 and 7z data files will be read and verified in the process.
#
# Instead of using 7z, this script could run a pipe like this:
#   tar -> encrypt -> pv -> file split
# The 'pv' command could then show how fast data is being backed up.
#
# About the par2 tool that creates the redundancy information:
#   Old 'par2' versions are very slow and single threaded. It is best to use
#   version 0.7.4, released in september 2017, or newer.
#
# Copyright (c) 2015-2021 R. Diez
# Licensed under the GNU Affero General Public License version 3.

set -o errexit
set -o nounset
set -o pipefail


declare -r BACKUP_NAME="BackupOfMyComputer"

# This script will create a subdirectory with all backup data under the following base directory:
BASE_DEST_DIR="./$BACKUP_NAME"

# We need an absolute path in the rest of the script.
BASE_DEST_DIR="$(readlink --canonicalize --verbose -- "$BASE_DEST_DIR")"

TARBALL_BASE_FILENAME="$BACKUP_NAME-$(date "+%F")"

TEST_SCRIPT_FILENAME_FIRST="test-backup-integrity-first-time.sh"
TEST_SCRIPT_FILENAME_SUBSEQUENT="test-backup-integrity-subsequent-times.sh"
REDUNDANT_DATA_REGENERATION_SCRIPT_FILENAME="regenerate-par2-redundant-data.sh"

SHOULD_DISPLAY_REMINDERS=true

# When testing this script, you may want to temporarily turn off compression and encryption,
# especially if your CPU is very slow.
SHOULD_COMPRESS=true

SHOULD_ENCRYPT=true
# If you leave the ENCRYPTION_PASSWORD variable below empty, you will be prompted for the password.
#
# SECURITY WARNING: Specifying the password in ENCRYPTION_PASSWORD below is completely insecure.
# The password will be visible in plain text inside this file, and possibly on any log file
# you keep of this script's execution. During execution, the password will also be visible
# as a command-line argument in the system's current process list (which usually anybody can see).
#
# There is apparently no secure way to pass the password to the 7z tool. You could pipe it to stdin,
# but that is risky, in case 7z decides to prompt for something else and echo the answer to stdout.
# Other tools can take a password from the environment or from an arbitrary file descriptor.
#
# Specifying the password here in an unsecure way is however sufficient if you want to take the
# hard disk outside premises and you are just worried that other, unrelated people could access the data.
ENCRYPTION_PASSWORD=""

SHOULD_GENERATE_REDUNDANT_DATA=true

# Remember that some filesystems have limitations on the maximum file size.
# For example, the popular FAT32 can only handle files up to one byte less than 4gigabytes.
declare -r FILE_SPLIT_SIZE="2g"
declare -r -i REDUNDANCY_PERCENTAGE="1"

# See further below for an explanation about how par2 option -m affects performance.
# par2's default is -m16 (16 MiB), which is very low nowadays.
# If your computer has enough memory, increasing this option so that all recovery data
# (the REDUNDANCY_PERCENTAGE from the total 7z file sizes) fits into memory will prevent
# a second pass on the data files and probably halve the overall processing time.
# Note that this scripts prints the estimated size of the recovery data
# for convenience after creating the tarballs.
declare -r -i PAR2_MEMORY_LIMIT_MIB="512"

# See further below for an explanation about how par2 option -T affects performance.
# par2's default is -T2.
# I am using mainly external USB disks and reasonably fast processors, so a value of 1 works best for me.
declare -r -i PAR2_PARALLEL_FILE_COUNT="1"

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

# Allowed values:
# - zenity
#   Zenity has window size issues with GTK 3 and has become unusable lately.
#   Therefore, YAD is recommended instead.
# - yad
# - console
#   In case you are using a text console and have no desktop environment.
DIALOG_METHOD="yad"

declare -r BOOLEAN_TRUE=0
declare -r BOOLEAN_FALSE=1

# declare -r EXIT_CODE_SUCCESS=0
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


divide_round_up ()
{
  local -r -i DIVIDEND="$1"
  local -r -i DIVISOR="$2"

  RESULT=$(( ( DIVIDEND + ( DIVISOR - 1 ) ) / DIVISOR ))
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


generate_integer_and_unit ()
{
  local -r -i INTEGER_VALUE="$1"
  local -r    WITH_THOUSANDS_SEPARATORS="$2"
  local -r    UNIT_NAME="$3"

  local PLURAL_SUFFIX=""

  if (( INTEGER_VALUE != 1 )); then
    PLURAL_SUFFIX="s"
  fi

  case "$WITH_THOUSANDS_SEPARATORS" in
    with-thousands)    printf -v INTEGER_AND_UNIT "%'d %s%s" "$INTEGER_VALUE" "$UNIT_NAME" "$PLURAL_SUFFIX";;
    without-thousands) printf -v INTEGER_AND_UNIT "%d %s%s"  "$INTEGER_VALUE" "$UNIT_NAME" "$PLURAL_SUFFIX";;
    *) abort "Invalid argument WITH_THOUSANDS_SEPARATORS of \"$WITH_THOUSANDS_SEPARATORS\".";;
  esac
}


get_human_friendly_elapsed_time ()
{
  local -i SECONDS="$1"

  local INTEGER_AND_UNIT

  if (( SECONDS <= 59 )); then
    generate_integer_and_unit "$SECONDS" "without-thousands" "second"
    ELAPSED_TIME_STR="$INTEGER_AND_UNIT"
    return
  fi

  local -i V="$SECONDS"

  generate_integer_and_unit "$(( V % 60 ))" "without-thousands" "second"

  ELAPSED_TIME_STR="$INTEGER_AND_UNIT"

  V="$(( V / 60 ))"

  generate_integer_and_unit "$(( V % 60 ))" "without-thousands" "minute"

  ELAPSED_TIME_STR="$INTEGER_AND_UNIT, $ELAPSED_TIME_STR"

  V="$(( V / 60 ))"

  if (( V > 0 )); then
    generate_integer_and_unit "$V" "with-thousands" "hour"

    ELAPSED_TIME_STR="$INTEGER_AND_UNIT, $ELAPSED_TIME_STR"
  fi

  generate_integer_and_unit "$SECONDS" "with-thousands" "second"

  ELAPSED_TIME_STR="$ELAPSED_TIME_STR ($INTEGER_AND_UNIT)"
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
  local TITLE="$1"
  local OK_BUTTON_CAPTION="$2"
  local MSG="$3"

  # Unfortunately, there is no way to set the cancel button to be the default.
  local CMD
  printf -v CMD  "%q --no-markup  --question --title %q  --text %q  --ok-label %q  --cancel-label \"Cancel\""  "$TOOL_ZENITY"  "$TITLE"  "$MSG"  "$OK_BUTTON_CAPTION"

  echo "$CMD"

  echo "Waiting for the user to close the confirmation window..."

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1) echo
       echo "The user cancelled the process."
       exit "$EXIT_CODE_ERROR";;  # We could also yield EXIT_CODE_SUCCESS,
                                  # but I guess the purpose of this script is to make a backup,
                                  # so cancelling it should be an error.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_ZENITY\"." ;;
  esac
}


display_reminder_zenity ()
{
  local TITLE="$1"
  local MSG="$2"

  local CMD
  printf -v CMD  "%q --no-markup  --info  --title %q  --text %q"  "$TOOL_ZENITY"  "$TITLE"  "$MSG"

  echo "$CMD"

  echo "Waiting for the user to close the reminder window..."

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
  local TITLE="$1"
  local OK_BUTTON_CAPTION="$2"
  local MSG="$3"

  # Unfortunately, there is no way to set the cancel button to be the default.
  # Option --fixed is a work-around to excessively tall windows with YAD version 0.38.2 (GTK+ 3.22.30).
  local CMD
  printf -v CMD \
         "%q --fixed --no-markup  --image dialog-question --title %q  --text %q  --button=%q:0  --button=gtk-cancel:1" \
         "$TOOL_YAD" \
         "$TITLE" \
         "$MSG" \
         "$OK_BUTTON_CAPTION!gtk-ok"

  echo "$CMD"

  echo "Waiting for the user to close the confirmation window..."

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0) : ;;
    1|252)  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
       echo
       echo "The user cancelled the process."
       exit "$EXIT_CODE_ERROR";;  # We could also yield EXIT_CODE_SUCCESS,
                                  # but I guess the purpose of this script is to make a backup,
                                  # so cancelling it should be an error.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


display_confirmation_console ()
{
  local TITLE="$1"
  local OK_BUTTON_CAPTION="$2"  # We are not using this when on a text console.
  local MSG="$3"

  echo
  echo "$TITLE"
  echo "$MSG"
  echo

  local USER_INPUT
  read -r -p "Please confirm with 'y' or 'yes' to continue: " USER_INPUT

  local -r USER_INPUT_UPPERCASE="${USER_INPUT^^}"

  case "$USER_INPUT_UPPERCASE" in
    Y|YES) echo ;;
    *) abort "The user did not confirm that the backup should continue.";;
  esac
}


display_reminder_yad ()
{
  local TITLE="$1"
  local MSG="$2"

  # Option --fixed is a work-around to excessively tall windows with YAD version 0.38.2 (GTK+ 3.22.30).
  local CMD
  printf -v CMD \
         "%q --fixed --no-markup  --image dialog-information  --title %q  --text %q --button=gtk-ok:0" \
         "$TOOL_YAD" \
         "$TITLE" \
         "$MSG"

  echo "$CMD"

  echo "Waiting for the user to close the reminder window..."

  set +o errexit
  eval "$CMD"
  local CMD_EXIT_CODE="$?"
  set -o errexit

  case "$CMD_EXIT_CODE" in
    0|252) : ;;  # If the user presses the ESC key, or closes the window, YAD yields an exit code of 252.
    *) abort "Unexpected exit code $CMD_EXIT_CODE from \"$TOOL_YAD\"." ;;
  esac
}


display_reminder_console ()
{
  local TITLE="$1"
  local MSG="$2"

  echo
  echo "$TITLE"
  echo "$MSG"
}


display_confirmation ()
{
  case "$DIALOG_METHOD" in
    zenity)  display_confirmation_zenity "$@";;
    yad)     display_confirmation_yad "$@";;
    console) display_confirmation_console "$@";;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac
}

display_reminder ()
{
  case "$DIALOG_METHOD" in
    zenity)  display_reminder_zenity "$@";;
    yad)     display_reminder_yad "$@";;
    console) display_reminder_console "$@";;
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
# Note that the new subdirectory name contains the date. If you happen to be working near midnight
# and re-run this script, it may not delete the backup from a few minutes ago,
# so that you could end up with 2 sets of backup files, yesterday's and today's.
#
# Therefore, it is best to create a separate base directory for each backup source.
# This way, the user will hopefully realise that in that particular case near midnight
# there are 2 directories with different dates. Otherwise, the user may not immediately realise
# that all files are duplicated and the backup is twice the usual size.

rm -fv -- "$DEST_DIR/$TARBALL_BASE_FILENAME"*  # The tarball gets splitted into files with extensions like ".001".
                                               # There are also ".par2" files to delete.

if [ -f "$DEST_DIR/$TEST_SCRIPT_FILENAME_FIRST" ]; then
  rm -fv -- "$DEST_DIR/$TEST_SCRIPT_FILENAME_FIRST"
fi

if [ -f "$DEST_DIR/$TEST_SCRIPT_FILENAME_SUBSEQUENT" ]; then
  rm -fv -- "$DEST_DIR/$TEST_SCRIPT_FILENAME_SUBSEQUENT"
fi

TARBALL_FILENAME="$DEST_DIR/$TARBALL_BASE_FILENAME.7z"

# Unfortunately, the 7-Zip version 16.02 that ships with Ubuntu 18.04 and 20.04 is rather old,
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
  printf  -v PASSWORD_OPTION -- "-p%q"  "$ENCRYPTION_PASSWORD"
  COMPRESS_CMD+=" $PASSWORD_OPTION"
fi


add_pattern_to_exclude "$HOME/MyBigTempDir1"
add_pattern_to_exclude "$HOME/MyBigTempDir2"


# Exclude all subdirectories everywhere that are called "Tmp".
COMPRESS_CMD+=" '-xr!Tmp'"

COMPRESS_CMD+=" --"

# You will probably want to backup the following easy-to-forget directories:
# - "$HOME/.ssh"         (your SSH encryption keys)
# - "$HOME/.thunderbird" (your Thunderbird mailbox)
# - "$HOME/.bashrc"      (your bash init script)
# - "$HOME/Desktop"      (your desktop icons and files)
# - This backup script itself. But beware that, if ENCRYPTION_PASSWORD contains the password
#   in plain text, you may want to delete the password from this script after restoring an encrypted backup.

add_pattern_to_backup "$HOME/MyDirectoryToBackup1"
add_pattern_to_backup "$HOME/MyDirectoryToBackup2"

COMPRESS_CMD+=" && popd >/dev/null"


if $SHOULD_DISPLAY_REMINDERS; then

  case "$DIALOG_METHOD" in
    zenity)  verify_tool_is_installed  "$TOOL_ZENITY"  "zenity";;
    yad)     verify_tool_is_installed  "$TOOL_YAD"     "yad";;
    console) ;;
    *) abort "Unknown reminder dialog method '$DIALOG_METHOD'.";;
  esac

  BEGIN_REMINDERS="The backup is about to begin:"$'\n'

  BEGIN_REMINDERS+="- Mount the backup destination disk."$'\n'
  BEGIN_REMINDERS+="- Check that the destination disk has enough free space."$'\n'
  BEGIN_REMINDERS+="- Set the system power settings to prevent your computer from going to sleep during the backup."$'\n'
  BEGIN_REMINDERS+="- Close Thunderbird."$'\n'
  BEGIN_REMINDERS+="- Close some other programs you often run that use files being backed up."$'\n'

  if $SHOULD_ENCRYPT && [ -z "$ENCRYPTION_PASSWORD" ]; then
    BEGIN_REMINDERS+="- Wait until the password prompt."$'\n'
    BEGIN_REMINDERS+="  Otherwise, if you leave the computer unattended, the backup will stall at the password prompt."$'\n'
    BEGIN_REMINDERS+="  7z does a first directory scan that can take a while, but hopefully it will not take too long."$'\n'
  fi

  BEGIN_REMINDERS+="- Place other reminders of yours here."$'\n'

  # Automatically remove any trailing end-of-line character (\n), and now that we are at it,
  # any other trailing whitespace too.
  BEGIN_REMINDERS="${BEGIN_REMINDERS%%+([[:space:]])}"

  display_confirmation "Backup Confirmation" "Start backup" "$BEGIN_REMINDERS"

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

# Try to flush the tarball files to disk as soon as possible.
# If par2 file generation fails, we can try again, as long as the tarball files are intact.
echo
echo "Flushing the write-back cache..."
sync

read_uptime_as_integer
declare -r BACKUP_FINISH_UPTIME="$UPTIME"
declare -r BACKUP_ELAPSED_SECONDS="$((BACKUP_FINISH_UPTIME - BACKUP_START_UPTIME))"
get_human_friendly_elapsed_time "$BACKUP_ELAPSED_SECONDS"
echo "Elapsed time backing up files: $ELAPSED_TIME_STR"

declare -r -i BYTES_IN_MIB=$(( 1024 * 1024 ))


TARBALLS_DU_OUTPUT="$(du  --apparent-size  --block-size=$BYTES_IN_MIB  --total "$DEST_DIR/$TARBALL_BASE_FILENAME.7z".* | tail --lines=1)"
# The first component is the data size. The second component is the word 'total', which we discard.
read -r TARBALLS_SIZE_MB _ <<<"$TARBALLS_DU_OUTPUT"

printf -v TARBALLS_SIZE_WITH_SEPARATORS_MB  "%'d"  "$TARBALLS_SIZE_MB"

# Multiplying by up to 100 could trigger an integer overflow. We hope that, if the amount of data is really large,
# this Bash is using 64-bit integers.
divide_round_up  "$(( TARBALLS_SIZE_MB * REDUNDANCY_PERCENTAGE ))"  100

printf -v RECOVERY_DATA_SIZE_WITH_SEPARATORS  "%'d"   "$RESULT"

printf -v PAR2_MEMORY_LIMIT_MIB_WITH_SEPARATORS  "%'d"   "$PAR2_MEMORY_LIMIT_MIB"

echo
echo "Tarballs size       : $TARBALLS_SIZE_WITH_SEPARATORS_MB MiB  (rounded up)"
echo "par2 size estimation: $RECOVERY_DATA_SIZE_WITH_SEPARATORS MiB  ($REDUNDANCY_PERCENTAGE % of tarballs rounded up, some overhead should be added)"
echo "par2 memory limit   : $PAR2_MEMORY_LIMIT_MIB_WITH_SEPARATORS MiB  (if lower, multiple read passes will ensue)"


pushd "$DEST_DIR" >/dev/null

# About par2 performance:
#
#   For more information see this GitHub issue I opened:
#     Understanding par2cmdline performance
#     https://github.com/Parchive/par2cmdline/issues/151
#
#   par2 performs two different 2 operations:
#
#    - Hashing (CRC32 and MD5) is performed to verify data integrity on both the source files and the par2 files.
#      Hashing tends to be I/O bound.
#      The verification operation only performs hashing.
#
#    - Recovery computation is performed to be able to repair missing or corrupt source files.
#      Recovery computation tends to be CPU bound.
#      The higher the percentage level of redundancy, the more CPU intensive.
#      Only the creation and repair operations need to perform recovery computation.
#
#   It is normally not necessary to provide a value for the -t argument (number of threads), because par2 will
#   auto-detect the number of CPU threads. In some environments, like when compiling with GNU Make, some people
#   report improvements using (number of hardware threads + 1) or even (* 2), but it is hard to say
#   what would be best for this par2 invocation. Option -t affects recovery computation, and not hashing.
#   Therefore, a higher -t value would help most with high percentages of redundant data.
#   Multithreading is only used during recovery computation, at least in par2 version 0.8.1 .
#
#   There is a -T argument that specifies the number of files hashed in parallel. See variable PAR2_PARALLEL_FILE_COUNT.
#   Hashing is performed both when creating and when verifying par2 files.
#   Whether increasing this argument helps depends on the kind of disk (HDD or SDD) that you have,
#   so it is hard for this script to make a good guess.
#   - On a fast SSD, increasing -T will take advantage of multicore processors, and hashing will be much faster.
#   - On a conventional HDD, if you read from several files simultaneously, the constant seeks will kill performance.
#     On an external USB 3.0 HDD drive I tested, any -T value above 1 causes a performance drop. Sometimes
#     hashing takes more than twice the time. I tested with par2 version 0.8.1 .
#
#   Argument -m specifies how much memory can be consumed during recovery computation (not hashing).
#   Therefore, it does not affect verification, only creation and repair.
#
#   The amount of recovery data is calculated from the total size of the source files and the percentage level
#   of redundancy.
#
#   - If the whole recovery data fits into memory (as specified by variable PAR2_MEMORY_LIMIT_MIB), then par2 performs
#     a single sequential scan of all files. During processing, there is a single progress indicator (a percentage value).
#
#   - If the whole recovery data does not fit into memory, then:
#
#     a) An extra scan is performed to hash the source files.
#        You then see an additional progress indicator (a  percentage value) in the 'Opening' phase (hashing).
#        Thus, if the source files (the tarballs) do not fit in the disk cache (they normally do not),
#        the process will take twice as long.
#
#     b) The source files are scanned multiple times (chunk mode), but on each pass, only part of the data
#        (a slice) is read from the source files. Therefore, there is a seek after every read.
#        The par2 files are also written in slices.
#        This phase is performed after progress message "Computing Reed Solomon matrix".
#        How many passes (slices) are performed depends on the block size and the memory limit.
#        Therefore, the bigger the memory limit, the better the overall performance will be,
#        depending on the size and layout of the disk's tracks and sectors.
#
#        Note that it is actually possible to mix chunked processing in phase (b) and hashing in phase (a),
#        at least to some extent, in order to save one read pass. This optimisation is not implemented
#        in par2 version 0.8.1, but it is in tool ParPar.
#
# About par2 progress indication:
#   If you do not specify the -q (quiet) option, par2 provides a progress indication as a percentage
#   (among other verbose output). I find that lacking. It would be best to have an estimation of the time left,
#   and even an estimated time of arrival (ETA). I have created a feature request for this here:
#     Provide some sort of progress indication
#     https://github.com/Parchive/par2cmdline/issues/124

printf -v GENERATE_REDUNDANT_DATA_CMD  "%q create -T$PAR2_PARALLEL_FILE_COUNT -r$REDUNDANCY_PERCENTAGE -m$PAR2_MEMORY_LIMIT_MIB -- %q %q.*"  "$TOOL_PAR2"  "$TARBALL_BASE_FILENAME.par2"  "$TARBALL_BASE_FILENAME.7z"

# If you are thinking about compressing the .par2 files, I have verified empirically
# that they do not compress at all. After all, they are derived from compressed,
# encrypted files.

printf -v TEST_TARBALL_CMD  "%q t -- %q"  "$TOOL_7Z"  "$TARBALL_BASE_FILENAME.7z.001"

printf -v VERIFY_PAR2_CMD  "%q verify -T$PAR2_PARALLEL_FILE_COUNT -- %q"  "$TOOL_PAR2"  "$TARBALL_BASE_FILENAME.par2"

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
  printf  -v ECHO_CMD  "echo %q"  "$TEST_TARBALL_CMD"
  echo "$ECHO_CMD"
  echo "$TEST_TARBALL_CMD"

  echo ""
  echo "shopt -s nullglob"
  echo ""
  echo "declare -a FILES=( *.par2 )  # Alternative: Use Bash built-in 'compgen'."
  echo ""
  echo "echo"
  echo ""

  echo "if (( \${#FILES[@]} == 0 )); then"
  echo "  echo \"No redundant files found to test.\""
  echo "else"
  echo "  echo \"Verifying the compressed files and their redundant records...\""
  printf  -v ECHO_CMD  "echo %q"  "$VERIFY_PAR2_CMD"
  echo "  $ECHO_CMD"
  echo "  $VERIFY_PAR2_CMD"
  echo "fi"

  echo ""
  echo "echo"
  echo "echo \"Finished testing the backup integrity, everything OK.\""

  # We could suppress the following message if there are no par2 files (yet).
  echo "echo \"After this first test, it is no longer necessary to test the compressed files\""
  echo "echo \"separately, so, if you wish to retest, use $TEST_SCRIPT_FILENAME_SUBSEQUENT instead.\""

} >"$TEST_SCRIPT_FILENAME_FIRST"

chmod a+x -- "$TEST_SCRIPT_FILENAME_FIRST"


{
  echo "#!/bin/bash"
  echo ""
  echo "set -o errexit"
  echo "set -o nounset"
  echo "set -o pipefail"
  echo ""

  # After this first test, it is no longer necessary to test the compressed files
  # separately, so, if you wish to retest, this script is faster.

  echo ""
  echo "shopt -s nullglob"
  echo ""
  echo "declare -a FILES=( *.par2 )  # Alternative: Use Bash built-in 'compgen'."
  echo ""

  echo "if (( \${#FILES[@]} == 0 )); then"
  echo "  echo \"No redundant files found to test. Testing the compressed files...\""
  printf  -v ECHO_CMD  "echo %q"  "$TEST_TARBALL_CMD"
  echo "  $ECHO_CMD"
  echo "  $TEST_TARBALL_CMD"
  echo "else"
  echo "  echo \"Verifying the compressed files and their redundant records...\""
  printf  -v ECHO_CMD  "echo %q"  "$VERIFY_PAR2_CMD"
  echo "  $ECHO_CMD"
  echo "  $VERIFY_PAR2_CMD"
  echo "fi"

  echo ""
  echo "echo"
  echo "echo \"Finished testing the backup integrity, everything OK.\""
} >"$TEST_SCRIPT_FILENAME_SUBSEQUENT"

chmod a+x -- "$TEST_SCRIPT_FILENAME_SUBSEQUENT"


{
  echo "#!/bin/bash"
  echo ""
  echo "set -o errexit"
  echo "set -o nounset"
  echo "set -o pipefail"
  echo ""

  echo "echo \"Deleting any existing redundant data files first...\""
  echo "$DELETE_PAR2_FILES_CMD"
  echo "echo"
  echo ""

  echo "echo \"Generating the par2 redundant data...\""
  printf  -v ECHO_CMD  "echo %q"  "$GENERATE_REDUNDANT_DATA_CMD"
  echo "$ECHO_CMD"
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

  if [[ $DIALOG_METHOD != "console" ]]; then
    display_desktop_notification "The backup process has finished" false
  fi

  END_REMINDERS="The backup process has finished."$'\n'
  END_REMINDERS+="Total backup size: $BACKUP_SIZE"$'\n'

  END_REMINDERS+="Reminders:"$'\n'
  END_REMINDERS+="- Unmount the destination disk."$'\n'
  END_REMINDERS+="- Restore the normal system power settings."$'\n'
  END_REMINDERS+="- Re-open Thunderbird."$'\n'
  END_REMINDERS+="- Now is a good time to compact the Thunderbird folders."$'\n'
  END_REMINDERS+="- Place other reminders of yours here."$'\n'
  END_REMINDERS+="- If you need to copy the files to external storage, consider using"$'\n'
  END_REMINDERS+="   script 'copy-with-rsync.sh'."$'\n'
  END_REMINDERS+="- You should test the compressed files on their final backup location once"$'\n'
  END_REMINDERS+="   with the generated '$TEST_SCRIPT_FILENAME_FIRST' script."$'\n'
  END_REMINDERS+="   Before testing, unmount and remount the disk. Otherwise,"$'\n'
  END_REMINDERS+="   the system's disk cache may falsify the result."$'\n'
  END_REMINDERS+="- You may also want to verify older backups to check whether the disk is reliable."$'\n'

  # Automatically remove any trailing end-of-line character (\n), and now that we are at it,
  # any other trailing whitespace too.
  END_REMINDERS="${END_REMINDERS%%+([[:space:]])}"

  display_reminder "Backup Reminder" "$END_REMINDERS"

fi

echo
echo "Finished creating backup files."
echo "Total backup size: $BACKUP_SIZE"
