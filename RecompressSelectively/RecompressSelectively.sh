#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


declare -r VERSION_NUMBER="1.02"
declare -r SCRIPT_NAME="RecompressSelectively.sh"

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
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


display_help ()
{
  echo
  echo "$SCRIPT_NAME version $VERSION_NUMBER"
  echo
  echo "Selectively recompress archive files (like zip files) across subdirectories."
  echo
  echo "Rationale:"
  echo "  Say you have a bunch of archive files (like zip files) spread over many subdirectories,"
  echo "  and you want to recompress them all."
  echo
  echo "  You would like to use another compression tool, like \"advzip --shrink-insane\","
  echo "  which uses the zopfli algorithm to very slowly compress as much as possible."
  echo "  Warning: advzip version 2.1-2.1build1 that comes with Ubuntu MATE 20.04"
  echo "           does not support international characters in filenames."
  echo
  echo "  But you want to skip some archives based on some filename criteria. In fact, it would"
  echo "  be nice use the full power of the 'find' tool."
  echo
  echo "  And you also want to skip some archives based on their contents. For example, only process"
  echo "  those archives with a particular filename inside."
  echo
  echo "  You also want to swap out some shared files in all recompressed archives, because those"
  echo "  common files have been updated in the meantime."
  echo
  echo "  At this point, you need so much flexibility, that you realise you will need to write"
  echo "  a custom script for this purpose. But there are more features to consider."
  echo
  echo "  Any temporary files should always land on the same subdirectory. This way, if something"
  echo "  fails, you can inspect them manually."
  echo
  echo "  Should you run two instances of the script at the same time by mistake, the second instance"
  echo "  should of course realise and stop, so as not to disturb the first one."
  echo
  echo "  The first time around, you want to test the recompression results locally, and not modify"
  echo "  the original archives, in case you have made a mistake somewhere."
  echo
  echo "  Writing such a script from scratch is time consuming, especially if you want it to be robust."
  echo "  That is why I have written a complete, robust example Bash script with all the features"
  echo "  described above. Every time I need such flexibility in a batch file operation, I can save"
  echo "  a lot of time by copying and modifying this example script."
  echo
  echo "Syntax:"
  echo "  $SCRIPT_NAME [options...] <start directory>"
  echo
  echo "Options:"
  echo " --help     displays this help text"
  echo " --version  displays the tool's version number (currently $VERSION_NUMBER)"
  echo " --license  prints license information"
  echo " --find-only  Run only the 'find' command and list any files found."
  echo " --output-dir <dir>  Instead of replacing the original archives,"
  echo "                     place the recompressed ones somewhere else."
  echo "                     If the output directory already exists, it will not be emptied beforehand."
  echo
  echo "How to test this script:"
  echo "  ./CreateTestFiles.sh  \"TestData\""
  echo "  ./$SCRIPT_NAME --output-dir=\"TestData/Output\"  \"TestData/FilesToProcess\""
  echo
  echo "Caveats:"
  echo "- File permissions are not respected. The recompressed archives will have default permissions,"
  echo "  unless you modify this script yourself."
  echo "- This script should use a temporary filesystem like /tmp, for performance reasons,"
  echo "  but that is not implemented yet. The main issue is making sure that any temporary files"
  echo "  are deleted if the script gets killed. There is not really a reliable way to achieve that."
  echo
  echo "Exit status: 0 means success, anything else is an error."
  echo
  echo "Feedback: Please send feedback to rdiezmail-tools at yahoo.de"
  echo
  echo "Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3"
}


display_license ()
{
cat - <<EOF

Copyright (c) 2020 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

EOF
}


process_command_line_argument ()
{
  case "$OPTION_NAME" in
    help)
        display_help
        exit $EXIT_CODE_SUCCESS
        ;;
    version)
        echo "$VERSION_NUMBER"
        exit $EXIT_CODE_SUCCESS
        ;;
    license)
        display_license
        exit $EXIT_CODE_SUCCESS
        ;;
    find-only)
        FIND_ONLY=true
        ;;
    output-dir)
        if [[ $OPTARG = "" ]]; then
          abort "Option --output-dir has an empty value.";
        fi
        OUTPUT_DIR="$OPTARG"
        ;;

    *)  # We should actually never land here, because parse_command_line_arguments() already checks if an option is known.
        abort "Unknown command-line option \"--${OPTION_NAME}\".";;
  esac
}


parse_command_line_arguments ()
{
  # The way command-line arguments are parsed below was originally described on the following page:
  #   http://mywiki.wooledge.org/ComplexOptionParsing
  # But over the years I have rewritten or amended most of the code myself.

  if false; then
    echo "USER_SHORT_OPTIONS_SPEC: $USER_SHORT_OPTIONS_SPEC"
    echo "Contents of USER_LONG_OPTIONS_SPEC:"
    for key in "${!USER_LONG_OPTIONS_SPEC[@]}"; do
      printf -- "- %s=%s\\n" "$key" "${USER_LONG_OPTIONS_SPEC[$key]}"
    done
  fi

  # The first colon (':') means "use silent error reporting".
  # The "-:" means an option can start with '-', which helps parse long options which start with "--".
  local MY_OPT_SPEC=":-:$USER_SHORT_OPTIONS_SPEC"

  local OPTION_NAME
  local OPT_ARG_COUNT
  local OPTARG  # This is a standard variable in Bash. Make it local just in case.
  local OPTARG_AS_ARRAY

  while getopts "$MY_OPT_SPEC" OPTION_NAME; do

    case "$OPTION_NAME" in

      -) # This case triggers for options beginning with a double hyphen ('--').
         # If the user specified "--longOpt"   , OPTARG is then "longOpt".
         # If the user specified "--longOpt=xx", OPTARG is then "longOpt=xx".

         if [[ "$OPTARG" =~ .*=.* ]]  # With this --key=value format, only one argument is possible.
         then

           OPTION_NAME=${OPTARG/=*/}
           OPTARG=${OPTARG#*=}
           OPTARG_AS_ARRAY=("")

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT != 1 )); then
             abort "Command-line option \"--$OPTION_NAME\" does not take 1 argument."
           fi

           process_command_line_argument

         else  # With this format, multiple arguments are possible, like in "--key value1 value2".

           OPTION_NAME="$OPTARG"

           if ! test "${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]+string_returned_if_exists}"; then
             abort "Unknown command-line option \"--$OPTION_NAME\"."
           fi

           # Retrieve the number of arguments for this option.
           OPT_ARG_COUNT=${USER_LONG_OPTIONS_SPEC[$OPTION_NAME]}

           if (( OPT_ARG_COUNT == 0 )); then
             OPTARG=""
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           elif (( OPT_ARG_COUNT == 1 )); then
             # If this is the last option, and its argument is missing, then OPTIND is out of bounds.
             if (( OPTIND > $# )); then
               abort "Option '--$OPTION_NAME' expects one argument, but it is missing."
             fi
             OPTARG="${!OPTIND}"
             OPTARG_AS_ARRAY=("")
             process_command_line_argument
           else
             OPTARG=""
             # OPTARG_AS_ARRAY is not standard in Bash. I have introduced it to make it clear that
             # arguments are passed as an array in this case. It also prevents many Shellcheck warnings.
             OPTARG_AS_ARRAY=("${@:OPTIND:OPT_ARG_COUNT}")

             if [ ${#OPTARG_AS_ARRAY[@]} -ne "$OPT_ARG_COUNT" ]; then
               abort "Command-line option \"--$OPTION_NAME\" needs $OPT_ARG_COUNT arguments."
             fi

             process_command_line_argument
           fi

           ((OPTIND+=OPT_ARG_COUNT))
         fi
         ;;

      *) # This processes only single-letter options.
         # getopts knows all valid single-letter command-line options, see USER_SHORT_OPTIONS_SPEC above.
         # If it encounters an unknown one, it returns an option name of '?'.
         if [[ "$OPTION_NAME" = "?" ]]; then
           abort "Unknown command-line option \"$OPTARG\"."
         else
           # Process a valid single-letter option.
           OPTARG_AS_ARRAY=("")
           process_command_line_argument
         fi
         ;;
    esac
  done

  shift $((OPTIND-1))
  ARGS=("$@")
}


# These are the filenames to be replaced or updated inside the archives.
# Filenames are searched recursively inside the archives.
# At the moment, no subdirectory paths are allowed here, only filenames.
declare -a FILENAMES_TO_REPLACE=()

# These are the files that will be copied to the archives, replacing the old ones.
# The must be absolute paths at the moment.
#
# For example, say that filename A is to be replaced, and is found in the archive
# with path "subdir/A". Say that the replacement is called "/somewhere/B".
# Then "subdir/A" will be deleted, and the replacement in the archive will be "subdir/B".
#
# If the replacement should still be named "subdir/A" in the archive, this script alone
# cannot do it. As a workaround, create a symlink /somewhere/A -> /somewhere/B,
# so that the replacement is also called "A" as far as this script is concerned.
declare -a NEW_FILES=()

# If the old and new filenames are the same, and you provide the MD5 checksum of the new file contents,
# then this script will skip recompression if the file had already been replaced. That saves quite a lot of time.
#
# An entry with value "-" means "do not bother checking the MD5, always recompress". If the old and new filenames differ,
# there is no need to provide the MD5 checksum, because the MD5 check is not performed anyway: if the old filename exists
# in the archive, the old file is deleted, the new one copied, and the archive is always recompressed.
#
# An MD5 checksum is actually not completely safe for checking if the file content has changed,
# but the chance of a collision is extremelly low.
declare -a NEW_FILES_MD5=()

declare -r STARTING_CWD="$PWD"

FILENAMES_TO_REPLACE+=( "FileToReplace1.txt" )
NEW_FILES+=( "$STARTING_CWD/TestData/ReplacementFiles/FileToReplace1.txt" )
NEW_FILES_MD5+=( bedef5cfe34dbaa94e5d62185f42c2da )  # The test replacement file has just one text line that reads "NewContent1".

FILENAMES_TO_REPLACE+=( "FileToReplace2.txt" )
NEW_FILES+=( "$STARTING_CWD//TestData/ReplacementFiles/FileToReplace2.txt" )
NEW_FILES_MD5+=( 241537a4e09c74df9604648429e11146 )  # The test replacement file has just one text line that reads "NewContent2".


declare -r -i FILENAMES_TO_REPLACE_COUNT=${#FILENAMES_TO_REPLACE[@]}

if (( FILENAMES_TO_REPLACE_COUNT != ${#NEW_FILES[@]} )); then
  abort "Arrays FILENAMES_TO_REPLACE and NEW_FILES do not have the same length."
fi

if (( ${#NEW_FILES[@]} != ${#NEW_FILES_MD5[@]} )); then
  abort "Arrays NEW_FILES and NEW_FILES_MD5 do not have the same length."
fi


process_archive ()
{
  local -r FILENAME="$1"

  echo

  if false; then

    # This branch recompresses all archives found.
    local SHOULD_UNPACK=true

  else

    # This branch checks whether any of the files inside the archive are to be replaced.
    # If not, then the archive is not recompressed.
    # You could use any other criteria here to decide whether to recompress the archive.

    local SHOULD_UNPACK=false

    echo "Looking at $FILENAME ..."

    local LIST_ZIP_CMD

    # Note that we are assuming here that no filenames will contain new-line characters.
    # If some do, the logic here will break.

    printf -v LIST_ZIP_CMD \
           "%q -Z1 %q" \
           "$UNZIP_TOOLNAME" \
           "$FILENAME"


    if false; then
      echo "$LIST_ZIP_CMD"
    fi

    local FILENAME_INSIDE_ARCHIVE
    local FILENAME_ONLY_INSIDE_ARCHIVE

    while IFS='' read -r FILENAME_INSIDE_ARCHIVE; do

      if false; then
        echo "Inside zip filename: $FILENAME_INSIDE_ARCHIVE"
      fi

      FILENAME_ONLY_INSIDE_ARCHIVE="${FILENAME_INSIDE_ARCHIVE##*/}"

      local INDEX
      local TO_REPLACE

      for (( INDEX = 0 ; INDEX < FILENAMES_TO_REPLACE_COUNT; ++INDEX )); do

        TO_REPLACE="${FILENAMES_TO_REPLACE[$INDEX]}"

        # Possible optimisation: Maybe checking the file length before unpacking could tell us whether the
        #                        file inside is already the new version.
        # Possible optimisation: We could record which files were detected that need replacing,
        #                        so that we do not need to scan the unpacked directory afterwards.

        if [[ $FILENAME_ONLY_INSIDE_ARCHIVE = "$TO_REPLACE" ]]; then
          echo "Found file that may need replacing: $TO_REPLACE"
          SHOULD_UNPACK=true
        fi

      done

    done < <( eval "$LIST_ZIP_CMD" )

  fi

  if $SHOULD_UNPACK; then
    decompress_archive "$FILENAME"
  else
    echo "Skipping the archive - no filenames to replace found inside."
  fi
}


decompress_archive ()
{
  local -r FILENAME="$1"

  echo "Unpacking $FILENAME ..."

  local -r FILENAME_ABS="$PWD/$FILENAME"

  local -r FILENAME_WITHOUT_DIR="${FILENAME_ABS##*/}"

  local -r UNPACK_DIR_ABS="$TMP_DIR_ABS/UnpackDir"

  local DELETE_UNPACK_DIR_CMD

  printf -v DELETE_UNPACK_DIR_CMD  "rm -rf %q"  "$UNPACK_DIR_ABS"

  eval "$DELETE_UNPACK_DIR_CMD"

  mkdir -- "$UNPACK_DIR_ABS"

  pushd "$UNPACK_DIR_ABS" >/dev/null

  "$UNZIP_TOOLNAME" -q "$FILENAME_ABS"

  local -a ALL_FILENAMES
  local SHOULD_RECOMPRESS

  replace_files

  if $SHOULD_RECOMPRESS; then

    local CMD

    if $USE_ADVZIP; then

      printf -v CMD \
             "%q  --quiet --add %q --shrink-insane" \
             "$ADVZIP_TOOLNAME" \
             "$RECOMPRESSED_ARCHIVE_DIR_ABS/$FILENAME_WITHOUT_DIR"
    else

      printf -v CMD \
             "%q  --quiet  -9  --recurse-paths  %q" \
             "$ZIP_TOOLNAME" \
             "$RECOMPRESSED_ARCHIVE_DIR_ABS/$FILENAME_WITHOUT_DIR"
    fi

    CMD+=" *"  # Do not use ALL_FILENAMES here, as it will not work properly if the archive had subdirectories.

    echo "$CMD"
    eval "$CMD"

    RECOMPRESSED_FILE_COUNT=$(( RECOMPRESSED_FILE_COUNT + 1 ))

    # We have compressed with another tool. Verify that the standard unzip tool understands the archive.
    # This step is optional.
    if true; then

      echo "Testing the generated archive..."

      printf -v CMD \
         "%q -t -q -q %q" \
         "unzip" \
         "$RECOMPRESSED_ARCHIVE_DIR_ABS/$FILENAME_WITHOUT_DIR"

      echo "$CMD"
      eval "$CMD"

    fi

    if [[ $OUTPUT_DIR_ABS = "" ]]; then
      mv -- "$RECOMPRESSED_ARCHIVE_DIR_ABS/$FILENAME_WITHOUT_DIR"  "$FILENAME_ABS"
    else

      if str_starts_with "$FILENAME" "/"; then
        abort "Absolute filenames in the found filenames not supported. The concrete filename was: $FILENAME"
      fi

      local -r DEST_FILENAME="$OUTPUT_DIR_ABS/$FILENAME"
      local -r DEST_DIR="${DEST_FILENAME%/*}"

      mkdir --parents -- "$DEST_DIR"

      if false; then
        echo "Moving recompressed archive to: $DEST_FILENAME"
      fi

      mv -- "$RECOMPRESSED_ARCHIVE_DIR_ABS/$FILENAME_WITHOUT_DIR"  "$DEST_FILENAME"
    fi

  else

    echo "Skipping because no file contents need to be replaced."

  fi

  popd >/dev/null

  eval "$DELETE_UNPACK_DIR_CMD"
}


replace_files ()
{
  SHOULD_RECOMPRESS=false

  # Possible optimisation: We could try to locate the files to replace, instead
  # of scanning all unpacked files.

  shopt -s globstar
  shopt -s nullglob

  ALL_FILENAMES=(**)

  local -r -i FILENAME_COUNT=${#ALL_FILENAMES[@]}
  local ARCHIVE_FILE_INDEX
  local FILENAME_INSIDE_ARCHIVE
  local FILENAME_ONLY_INSIDE_ARCHIVE

  for (( ARCHIVE_FILE_INDEX = 0 ; ARCHIVE_FILE_INDEX < FILENAME_COUNT; ++ARCHIVE_FILE_INDEX )); do

    FILENAME_INSIDE_ARCHIVE="${ALL_FILENAMES[$ARCHIVE_FILE_INDEX]}"

    if false; then
      echo "Unpacked filename: $FILENAME_INSIDE_ARCHIVE"
    fi

    FILENAME_ONLY_INSIDE_ARCHIVE="${FILENAME_INSIDE_ARCHIVE##*/}"

    local FILENAME_ONLY_INSIDE_ARCHIVE
    local INDEX
    local TO_REPLACE
    local MD5
    local REPLACEMENT_FILENAME
    local REPLACEMENT_FILENAME_ONLY
    local MD5_OF_REPLACEMENT_FILE_CONTENT
    local SHOULD_REPLACE_FILE
    local DIRNAME_ONLY_INSIDE_ARCHIVE

    for (( INDEX = 0 ; INDEX < FILENAMES_TO_REPLACE_COUNT; ++INDEX )); do

      TO_REPLACE="${FILENAMES_TO_REPLACE[$INDEX]}"

      if [[ $FILENAME_ONLY_INSIDE_ARCHIVE = "$TO_REPLACE" ]]; then

        REPLACEMENT_FILENAME="${NEW_FILES[$INDEX]}"
        REPLACEMENT_FILENAME_ONLY="${REPLACEMENT_FILENAME##*/}"
        MD5_OF_REPLACEMENT_FILE_CONTENT="${NEW_FILES_MD5[$INDEX]}"

        if [[ $MD5_OF_REPLACEMENT_FILE_CONTENT = "-" ]]; then
          SHOULD_REPLACE_FILE=true
        else
          if [[ $TO_REPLACE = "$REPLACEMENT_FILENAME_ONLY" ]]; then

            MD5="$(md5sum "$FILENAME_INSIDE_ARCHIVE")"
            MD5="${MD5%% *}"  # Remove the first space and everything afterwards.

            if [[ $MD5 = "$MD5_OF_REPLACEMENT_FILE_CONTENT" ]]; then
              echo "No need to replace content of file: $TO_REPLACE"
              SHOULD_REPLACE_FILE=false
            else
              SHOULD_REPLACE_FILE=true
            fi
          else
            SHOULD_REPLACE_FILE=true
          fi
        fi

        if $SHOULD_REPLACE_FILE; then

          if [[ $TO_REPLACE = "$REPLACEMENT_FILENAME_ONLY" ]]; then
            echo "Replacing content of file: $FILENAME_INSIDE_ARCHIVE"
            cp -- "$REPLACEMENT_FILENAME"  "$FILENAME_INSIDE_ARCHIVE"
          else
            printf "Replacing file %q with %q .\n" "$FILENAME_INSIDE_ARCHIVE" "$REPLACEMENT_FILENAME_ONLY"

            rm -- "$FILENAME_INSIDE_ARCHIVE"

            DIRNAME_ONLY_INSIDE_ARCHIVE="${FILENAME_INSIDE_ARCHIVE%/*}"

            # If there is no subdir (the file is at root-level inside the archive), then extracting the subdir will not actually work
            # and the resulting subdir name will be the same as the complete filename.
            if [[ $DIRNAME_ONLY_INSIDE_ARCHIVE = "$FILENAME_INSIDE_ARCHIVE" ]]; then
              cp -- "$REPLACEMENT_FILENAME"  .
            else
              cp -- "$REPLACEMENT_FILENAME"  "$DIRNAME_ONLY_INSIDE_ARCHIVE/$REPLACEMENT_FILENAME_ONLY"
            fi
          fi

          SHOULD_RECOMPRESS=true
        fi

      fi

    done
  done
}


# Create a lock file in order to prevent 2 instances of this script
# using the same temporary directory at the same time.

create_lock_file ()
{
  set +o errexit
  exec {LOCK_FILE_FD}>"$LOCK_FILENAME_ABS"
  local EXIT_CODE="$?"
  set -o errexit

  if (( EXIT_CODE != 0 )); then
    abort "Cannot create or write to lock file \"$LOCK_FILENAME_ABS\"."
  fi
}


lock_lock_file ()
{
  # We are using an advisory lock here, not a mandatory one, which means that a process
  # can choose to ignore it. We always check whether the file is already locked,
  # so this type of lock is fine for our purposes.
  set +o errexit
  flock --exclusive --nonblock "$LOCK_FILE_FD"
  local EXIT_CODE="$?"
  set -o errexit

  if (( EXIT_CODE != 0 )); then
    abort "Cannot lock file \"$LOCK_FILENAME_ABS\". Is there another instance of this script ($SCRIPT_NAME) already running on the same directory?"
  fi
}


remove_lock_file ()
{
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
  rm -- "$LOCK_FILENAME_ABS"
}


# ----------- Entry point -----------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [find-only]=0 )
USER_LONG_OPTIONS_SPEC+=( [output-dir]=1 )

FIND_ONLY=false
OUTPUT_DIR=""

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} != 1 )); then
  abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information."
fi

declare -r START_DIR="${ARGS[0]}"


if [[ $OUTPUT_DIR = "" ]]; then
  OUTPUT_DIR_ABS=""
else
  mkdir --parents -- "$OUTPUT_DIR"
  OUTPUT_DIR_ABS="$(readlink  --verbose  --canonicalize-existing -- "$OUTPUT_DIR")"
fi


declare -r UNZIP_TOOLNAME="unzip"

verify_tool_is_installed "$UNZIP_TOOLNAME" "unzip"

declare -r USE_ADVZIP=false

# Tool 'pigz' does not support creating normal zip files, so I am using advzip instead.
declare -r ZIP_TOOLNAME="zip"
declare -r ADVZIP_TOOLNAME="advzip"

if $USE_ADVZIP; then
  verify_tool_is_installed "$ADVZIP_TOOLNAME" "advancecomp"
else
  verify_tool_is_installed "$ZIP_TOOLNAME" "zip"
fi

if ! $FIND_ONLY; then

  declare -r TMP_SUBDIR="tmp"

  declare -r LOCK_FILENAME_ABS="$PWD/$TMP_SUBDIR.lock"

  create_lock_file
  lock_lock_file


  declare -r TMP_DIR_ABS="$PWD/$TMP_SUBDIR"

  echo "Temporary directory: $TMP_DIR_ABS"

  printf -v DELETE_TMP_DIR_CMD  "rm -rf %q"  "$TMP_DIR_ABS"

  eval "$DELETE_TMP_DIR_CMD"

  mkdir --parents -- "$TMP_DIR_ABS"


  # The archives can be called anything, so place them in a subdirectory
  # in order to prevent name collisions.

  declare -r RECOMPRESSED_ARCHIVE_DIR_ABS="$TMP_DIR_ABS/RecompressedArchiveDir"

  mkdir -- "$RECOMPRESSED_ARCHIVE_DIR_ABS"

fi


pushd "$START_DIR" >/dev/null

declare -i RECOMPRESSED_FILE_COUNT=0

# This is the command you need to adjust in order to find the archives to be processed.

printf -v FIND_CMD \
       "find . -type f -iname %q  -printf %q" \
       "Sub*.zip" \
       "%P\\0"

echo "$FIND_CMD"

while IFS='' read -r -d '' FILENAME; do

  if $FIND_ONLY; then
    echo "$FILENAME"
    continue
  fi

  process_archive "$FILENAME"

done < <( eval "$FIND_CMD" )

popd >/dev/null

if ! $FIND_ONLY; then
  eval "$DELETE_TMP_DIR_CMD"
  remove_lock_file
fi

echo
echo "Finished. $RECOMPRESSED_FILE_COUNT file(s) were recompressed."
