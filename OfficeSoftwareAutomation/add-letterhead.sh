#!/bin/bash

# This script adds extra content in the background (typically a letterhead or watermark)
# to all pages of a PDF document.
#
# The extra content comes from a second PDF file. The path to that second PDF file is hard-coded
# in this script, see LETTERHEAD_FILENAME. You will also need to adjust MAGIC_STRING_IN_LETTERHEAD.
#
# The resulting PDF either replaces the original file, or is placed next to it, see FINAL_FILENAME_SUFFIX.
#
# You need the pdftk tool installed on your system, which is no longer in the Ubuntu/Debian package repository.
# If you install the corresponding Ubuntu Snap package, see COPY_LETTERHEAD_TO_LOCAL for caveats.
#
# Alternatively, this script could use tool qpdf version 8.4 or later, see options --overlay and --underlay .
# But that is not implemented yet.
#
# Copyright (c) 2016-2020 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

declare -r SCRIPT_BASENAME="add-letterhead"
declare -r SCRIPT_NAME="$SCRIPT_BASENAME.sh"

# At the moment this version number is only used for documentation purpuses:
# declare -r SCRIPT_VERSION="2.00"

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1


# Specify here your own PDF file with the background contents.
declare -r LETTERHEAD_FILENAME="/full/path/to/letterhead.pdf"


# If this suffix is not empty, the original PDF will be left untouched, and a new one
# with the letterhead will be created next to it, but with the given suffix.
# For example, file.pdf -> file-with-letterhead.pdf
declare -r FINAL_FILENAME_SUFFIX="-with-letterhead"


# On my Ubuntu 18.04.4 system, I installed pdftk as a Snap package, and then this
# pdftk version 2.02-4 could not open the letterhead file if it was located on a mounted network share.
# The error was:
#   Error: Failed to open background PDF file
# It turns out that Snap packages are "confined" by default. The /tmp directory is also prohibited.
# Symbolic links that point to other filesystems do not work either.
# Rather than playing with Snap system permissions, I decided to add an option to copy the file to
# a local directory beforehand. This local directory must be under $HOME.
#
# Note that, if you use this option, you can only run one instance of this script at a time.
# Any second, concurrent instance will fail to acquire a lock file created next to
# the letterhead copy. Because this script is mainly designed for interactive usage,
# this limitation should not be important.
# If it is, consider removing option --nonblock from flock below. But keep in mind then
# that this script might hang for a long time, or even forever, if something is not quite right.
# Depending on how you are using this script, you may not see any error message.

declare -r COPY_LETTERHEAD_TO_LOCAL=false
declare -r LOCAL_LETTERHEAD_FILENAME="$HOME/letterhead-file-for-$SCRIPT_BASENAME.pdf"


# Specify here the magic string to be found inside your letterhead PDF file.
#
# This script checks for the magic string in all 3 files: it should not be in the original document,
# but it should be in the letterhead, and in the resulting document. Therefore, it should be pretty difficult
# to make a mistake when the magic string is in place.
#
# - If your magic string is text:
#
#   Use a tool like pdftotext in order to extract text from the letterhead PDF.
#
#   Note that searching for a binary string is much faster, because tool 'grep' does not need to
#   process the complex PDF file format like tool 'pdfgrep' does.
#
# - If your magic string is binary:
#
#   In order to find a good magic string, manuall use pdftk to add the letterhead to a document.
#   Then use a text editor like Emacs in order to search for a suitable data stream (look for 'stream' and 'endstream')
#   that is present in both the letterhead PDF and the final document, but not in the original document.
#   Then take the first bytes and place them in the variable below.
#   For example, such a magic stream could look like this:
#     declare -r MAGIC_STRING_IN_LETTERHEAD=$'abc\101\102\103def'
#

declare -r IS_MAGIC_STRING_TEXT=true

declare -r MAGIC_STRING_IN_LETTERHEAD="TextThatIsOnlyInLetterhead"


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


is_tool_installed ()
{
  if command -v "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  if is_tool_installed "$TOOL_NAME"; then
    return
  fi

  local ERR_MSG="Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager."

  if [[ $DEBIAN_PACKAGE_NAME != "" ]]; then
    ERR_MSG+=" For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
  fi

  abort "$ERR_MSG"
}


if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi

declare -r PDF_FILENAME="$1"


declare -r PDFTK_TOOLNAME="pdftk"

# pdftk is no longer in the Ubuntu/Debian repositories.
verify_tool_is_installed "$PDFTK_TOOLNAME" ""

declare -r PDFGREP_TOOLNAME="pdfgrep"

if $IS_MAGIC_STRING_TEXT; then
  verify_tool_is_installed "$PDFGREP_TOOLNAME" "pdfgrep"
fi


declare -r FILE_EXTENSION="${PDF_FILENAME##*.}"
declare -r FILE_EXTENSION_UPPERCASE=${FILE_EXTENSION^^}

declare -r EXTENSION="PDF"

if [[ $FILE_EXTENSION_UPPERCASE != "$EXTENSION" ]]; then
  abort "This script operates only on .pdf files"
fi


declare -r -i EXTENSION_LEN="${#EXTENSION}"
declare -r PDF_FILENAME_WITHOUT_EXT="${PDF_FILENAME::-$(( EXTENSION_LEN + 1 ))}"

if [[ $PDF_FILENAME_WITHOUT_EXT = "" ]]; then
  abort "The PDF filename contains nothing but the file extension."
fi

if [[ $FINAL_FILENAME_SUFFIX = "" ]]; then
  declare -r FINAL_FILENAME="$PDF_FILENAME"
else
  declare -r FINAL_FILENAME="${PDF_FILENAME_WITHOUT_EXT}${FINAL_FILENAME_SUFFIX}.${FILE_EXTENSION}"
fi


set +o errexit
if $IS_MAGIC_STRING_TEXT; then
  "$PDFGREP_TOOLNAME" --quiet --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$LETTERHEAD_FILENAME"
else
  grep  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$LETTERHEAD_FILENAME"
fi
GREP_EXIT_CODE="$?"
set -o errexit

case "$GREP_EXIT_CODE" in
  0) ;;  # Nothing to do here.
  1) abort "The letterhead file does not contain the magic string.";;
  2) exit "$GREP_EXIT_CODE";;  # grep has printed an error message already.
  *) abort "Unexpected exit code $GREP_EXIT_CODE from grep.";;
esac


set +o errexit
if $IS_MAGIC_STRING_TEXT; then
  "$PDFGREP_TOOLNAME"  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$PDF_FILENAME"
else
  grep  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$PDF_FILENAME"
fi
GREP_EXIT_CODE="$?"
set -o errexit

case "$GREP_EXIT_CODE" in
  0) abort "The given file already has the letterhead.";;
  1) ;;  # Nothing to do here.
  2) exit "$GREP_EXIT_CODE";;  # grep has printed an error message already.
  *) abort "Unexpected exit code $GREP_EXIT_CODE from grep.";;
esac


if $COPY_LETTERHEAD_TO_LOCAL; then

  echo "Copying $LETTERHEAD_FILENAME to $LOCAL_LETTERHEAD_FILENAME ..."

  # Create a lock file in order to prevent 2 instances of this script overwriting
  # the LOCK_FILENAME file at the same time.

  declare -r LOCK_FILENAME="$LOCAL_LETTERHEAD_FILENAME.lock"

  if false; then
    echo "Creating lock file '$LOCK_FILENAME'..."
  fi

  set +o errexit
  exec {LOCK_FILE_FD}>"$LOCK_FILENAME"
  EXIT_CODE="$?"
  set -o errexit

  if (( EXIT_CODE != 0 )); then
    abort "Cannot create or write to lock file \"$LOCK_FILENAME\"."
  fi

  # We are using an advisory lock here, not a mandatory one, which means that a process
  # can choose to ignore it. We always check whether the file is already locked,
  # so this type of lock is fine for our purposes.
  set +o errexit
  flock --exclusive --nonblock "$LOCK_FILE_FD"
  EXIT_CODE="$?"
  set -o errexit

  if [ $EXIT_CODE -ne 0 ]; then
    abort "Cannot lock file \"$LOCK_FILENAME\". Is there another instance of this script ($SCRIPT_NAME) already running?"
  fi

  cp -- "$LETTERHEAD_FILENAME" "$LOCAL_LETTERHEAD_FILENAME"

  declare -r LETTERHEAD_FILENAME_TO_USE="$LOCAL_LETTERHEAD_FILENAME"
else
  declare -r LETTERHEAD_FILENAME_TO_USE="$LETTERHEAD_FILENAME"
fi


# The pdftk installed as a Snap package cannot access the /temp directory either.
# It is probably a good idea anyway to create the temporary file next to the output file.
declare -r USE_TMP_FILE_IN_TMP_DIR=false

if $USE_TMP_FILE_IN_TMP_DIR; then

  TMP_FILENAME="$(mktemp --tmpdir "tmp.$SCRIPT_BASENAME.doc-with-letterhead.XXXXXXXXXX.pdf")"

  if false; then
    echo "TMP_FILENAME: $TMP_FILENAME"
  fi

  # Try to delete the temporary file on exit. It is no hard guarantee,
  # but it usually works. If not, hopefully the operating system
  # will clean the temporary directory every now and then.
  printf -v TRAP_DELETE_CMD  "rm -f -- %q"  "$TMP_FILENAME"

  # shellcheck disable=SC2064
  trap "$TRAP_DELETE_CMD" EXIT

else

  TMP_FILENAME="$PDF_FILENAME.$SCRIPT_BASENAME-in-progress"

fi


printf  -v CMD \
        "%q  %q  background %q  output %q" \
        "$PDFTK_TOOLNAME" \
        "$PDF_FILENAME" \
        "$LETTERHEAD_FILENAME_TO_USE" \
        "$TMP_FILENAME"

echo "$CMD"
eval "$CMD"


# Release the lock.

if $COPY_LETTERHEAD_TO_LOCAL; then

  # Close the lock file, which releases the lock we have on it.
  exec {LOCK_FILE_FD}>&-

  # Delete the lock file, which is actually an optional step, as this script will run fine
  # next time around if the file already exists.
  # The lock file survives if you kill the script with a signal like Ctrl+C, but that is a good thing,
  # because the presence of the lock file will probably remind the user that the background process
  # was abruptly interrupted.
  # There is the usual trick of deleting the file upon creation, in order to make sure that it is
  # always deleted, even if the process gets killed. However, it is not completely safe,
  # as the process could get killed right after creating the file but before deleting it.
  # Furthermore, it is confusing, for the file still exists but it is not visible. Finally, I am not sure
  # whether flock will work properly if a second process attempts to create a new lock file with
  # the same name as the deleted, hidden one.
  rm -- "$LOCK_FILENAME"
fi


set +o errexit
if $IS_MAGIC_STRING_TEXT; then
  "$PDFGREP_TOOLNAME"  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$TMP_FILENAME"
else
  grep  --quiet  --fixed-strings "$MAGIC_STRING_IN_LETTERHEAD" "$TMP_FILENAME"
fi
GREP_EXIT_CODE="$?"
set -o errexit

case "$GREP_EXIT_CODE" in
  0) ;;  # Nothing to do here.
  1) abort "The generated PDF file does not contain the letterhead magic string.";;
  2) exit "$GREP_EXIT_CODE";;  # grep has printed an error message already.
  *) abort "Unexpected exit code $GREP_EXIT_CODE from grep.";;
esac


if $USE_TMP_FILE_IN_TMP_DIR; then
  # We could use here 'mv' instead, but then we should really cancel the "trap EXIT" above.
  cp -- "$TMP_FILENAME"  "$FINAL_FILENAME"
else
  mv -- "$TMP_FILENAME"  "$FINAL_FILENAME"
fi
