#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.


declare -r VERSION_NUMBER="1.14"
declare -r SCRIPT_NAME="unpack.sh"

declare -r -i BOOLEAN_TRUE=0
declare -r -i BOOLEAN_FALSE=1

declare -r -i EXIT_CODE_SUCCESS=0
declare -r -i EXIT_CODE_ERROR=1


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2019-2023 R. Diez - Licensed under the GNU AGPLv3

Overview:

This script unpacks an archive (zip, tarball, ISO image, etc.) into a subdirectory
inside the current directory (or the given destination directory), taking care that:
1) The destination directory does not get littered with many unpacked files.
2) No existing file or subdirectory is accidentaly overwritten.
3) The new file or subdirectory has a reasonable name, and that name
   is displayed at the end.

Rationale:

There are many types of archives, an unpacking each type needs a different
tool with different command-line options. I can never remember them.

All archive types do have something in common: when unpacking,
you never know in advance whether you are going to litter the destination
directory with the extracted files, or whether everything is going into
a subdirectory, and what that subdirectory is going to be called.

Because of that, I have become accustomed to opening such files beforehand
with the current desktop's file manager and archiving tool. Some
file managers, like KDE's Dolphin, often have an "Extract here,
autodetect subfolder" option, but not all do, or maybe the right plug-in
for the file manager is not installed yet. Besides, if you are connected
to a remove server via SSH, you may not have a quick desktop
environment available.

So I felt it was time to write this little script to automate unpacking
in a safe and convenient manner.

This script creates a temporary subdirectory in the destination directory,
unpacks the archive there, and then it checks what files were unpacked.

Many archives in the form program-version-1.2.3.zip contain a subdirectory
called program-version-1.2.3/ with all other files inside it. This script
will then place that subdirectory program-version-1.2.3/
in the destination directory.

Other archives in the form archive.zip have contain many top-level files.
This script will then unpack those files into an archive/ subdirectory.

If the archive contains just one file, it will be placed in the destination directory.

In any case, if the desired destination file or directory already exists,
this script will not overwrite it. Instead, a temporary directory like
archive-unpacked-wtGQX will be left behind.

In the end, the user will be told where the unpacked archive contents are
and, where appropriate, that the normally-expected unpacked name already existed.

This script is designed for interactive usage and is not suitable
for automated tasks.

For convenience, it is recommended that you place this script
on your PATH. In this respect, see also GenerateLinks.sh in the same Git
repository this script lives in.

Alternative scripts that work in a similar fashion:
  https://github.com/mitsuhiko/unp
  https://github.com/githaff/unpack

Syntax:
  $SCRIPT_NAME <options...> [--] <archive filename> [optional destination directory]

If the destination directory is not given, the current directory is used.

Options:
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example:
  $SCRIPT_NAME archive.zip

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license ()
{
cat - <<EOF

Copyright (c) 2019-2023 R. Diez

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
           fi;

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


add_extension ()
{
  local EXT="$1"
  local FN="$2"

  if test "${ALL_EXTENSIONS[$EXT]+string_returned_ifexists}"; then
    abort "Internal error: Extension \"$EXT\" is duplicated."
  fi

  ALL_EXTENSIONS["$EXT"]="$FN"
}


str_ends_with ()
{
  # $1 = string
  # $2 = suffix

  case "$1" in
     *$2) return $BOOLEAN_TRUE;;
     *)   return $BOOLEAN_FALSE;;
  esac
}


add_all_extensions ()
{
  add_extension .tar      unpack_tar

  add_extension .tar.gz   unpack_tar
  add_extension .tgz      unpack_tar

  add_extension .tar.bz2  unpack_tar
  add_extension .tb2      unpack_tar
  add_extension .tbz      unpack_tar
  add_extension .tbz2     unpack_tar

  add_extension .tar.lzma unpack_tar
  add_extension .tlz      unpack_tar

  # tar needs tool 'lzip' to decompress .tar.lz files, but 'lzip' is often not installed by default.
  # There is no short suffix for .tar.lz . Suffix .tlz is alreay taken by .tar.lzma .
  add_extension .tar.lz   unpack_tar

  add_extension .tar.xz   unpack_tar
  add_extension .txz      unpack_tar

  add_extension .tar.Z    unpack_tar
  add_extension .tZ       unpack_tar

  add_extension .7z       unpack_7z
  add_extension .zip      unpack_zip

  # For ISO images, alternatively use:
  # - isoinfo -i image.iso -R  # But you get "CD-ROM is NOT in ISO 9660 format" for some ISO images in UDF or other formats.
  # - bsdtar -xf image.iso     # Not tested yet.
  # We could try to extract the CD-ROM label inside (if any) and use it for the directory name.
  add_extension .iso      unpack_7z

  # .gz files typically contain only one compressed file. The data structure could allow for several files,
  # but most tools assume all compressed data chunks belong to a single file.
  add_extension .gz       unpack_gunzip

  # .Z files are no archives, they only contain a single compressed file.
  add_extension .Z        unpack_uncompress

  # .xz files are no archives, they only contain a single compressed file.
  # Note that extension .tar.xz is handled separately above.
  add_extension .xz       unpack_xz
}


is_tool_installed ()
{
  if type "$1" >/dev/null 2>&1 ;
  then
    return $BOOLEAN_TRUE
  else
    return $BOOLEAN_FALSE
  fi
}


verify_tool_is_installed ()
{
  if ! is_tool_installed "$1"; then
    abort "Tool '$1' is not installed. You may have to install it with your Operating System's package manager."
  fi
}


unpack_tar ()
{
  local TAR_TOOL="tar"

  verify_tool_is_installed "$TAR_TOOL"

  local CMD
  printf -v CMD  "%q --auto-compress --extract --file %q"  "$TAR_TOOL"  "$ARCHIVE_FILENAME_ABS"

  echo "$CMD"
  eval "$CMD"
}


unpack_zip ()
{
  local ZIP_TOOL="unzip"

  verify_tool_is_installed "$ZIP_TOOL"

  local CMD
  printf -v CMD  "%q -q -- %q"  "$ZIP_TOOL"  "$ARCHIVE_FILENAME_ABS"

  echo "$CMD"
  eval "$CMD"
}


unpack_7z ()
{
  local SEVENZ_TOOL="7z"

  verify_tool_is_installed "$SEVENZ_TOOL"

  # Unfortunately, 7z does not have a "quiet" option.
  # We could redirect all output to /dev/null, but then you would not
  # see an eventual password prompt.
  # Recent versions have options -bsp0 -bso0, but my current version is too old.

  local CMD
  printf -v CMD  "%q x -- %q"  "$SEVENZ_TOOL"  "$ARCHIVE_FILENAME_ABS"

  echo "$CMD"
  eval "$CMD"
}


unpack_gunzip ()
{
  local GUNZIP_TOOL="gunzip"

  verify_tool_is_installed "$GUNZIP_TOOL"

  local CMD
  printf -v CMD  "%q --to-stdout -- %q >%q" \
         "$GUNZIP_TOOL" \
         "$ARCHIVE_FILENAME_ABS" \
         "$ARCHIVE_NAME_ONLY_WITHOUT_EXT"

  echo "$CMD"
  eval "$CMD"
}


unpack_uncompress ()
{
  # Normally, the "uncompress" tool is actually a compatible alternative that comes with the gzip package.
  # We could specify here "uncompress.real" to use the original version, at least on Ubuntu/Debian.
  # I have actually tested with uncompress.real, and it does work.
  local UNCOMPRESS_TOOL="uncompress"

  verify_tool_is_installed "$UNCOMPRESS_TOOL"

  # The old 'uncompress' tool did not have a '--' separator between options and filename.
  local CMD
  printf -v CMD  "%q -c %q >%q" \
         "$UNCOMPRESS_TOOL" \
         "$ARCHIVE_FILENAME_ABS" \
         "$ARCHIVE_NAME_ONLY_WITHOUT_EXT"

  echo "$CMD"
  eval "$CMD"
}


unpack_xz ()
{
  local UNCOMPRESS_TOOL="xz"

  verify_tool_is_installed "$UNCOMPRESS_TOOL"

  # We would normally use flags "--decompress --keep", but the decompressed file
  # would then land next to the compressed one, and not in the current directory.

  local CMD
  printf -v CMD  "%q --decompress --to-stdout -- %q >%q" \
         "$UNCOMPRESS_TOOL" \
         "$ARCHIVE_FILENAME_ABS" \
         "$ARCHIVE_NAME_ONLY_WITHOUT_EXT"

  echo "$CMD"
  eval "$CMD"
}


# ------- Entry point -------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )

parse_command_line_arguments "$@"

case "${#ARGS[@]}" in
  1)  declare -r OUTPUT_DIRNAME="$PWD";;
  2)  declare -r OUTPUT_DIRNAME="${ARGS[1]}";;
  *) abort "Invalid number of command-line arguments. Run this tool with the --help option for usage information.";;
esac

if [ ! -d "$OUTPUT_DIRNAME" ]; then
  abort "Output directory does not exist: $OUTPUT_DIRNAME"
fi

declare -r ARCHIVE_FILENAME="${ARGS[0]}"

# readlink below will print an error message if the archive does not exist,
# so we do not need to do it ourselves.
if false; then
  if ! [ -f "$ARCHIVE_FILENAME" ]; then
    abort "Archive \"$ARCHIVE_FILENAME\" does not exist."
  fi
fi

ARCHIVE_FILENAME_ABS="$(readlink --canonicalize-existing --verbose -- "$ARCHIVE_FILENAME")"


# Sometimes I do not realise that the archive has already been uncompressed:
# I just type the first filename letters, press the Tab key for autocompletion,
# and run this script without really looking. The "Unknown archive type" error message
# comes as then a surprise, and it takes a couple of seconds forme to realise what is going on.
#
# In order to prevent that from happening yet again, I added this check, which
# generates a better error message in this common scenario.

if [ -d "$ARCHIVE_FILENAME_ABS" ]; then
  abort "File \"$ARCHIVE_FILENAME\" is actually a directory."
fi


declare -A ALL_EXTENSIONS

add_all_extensions

LONGEST_EXTENSION_MATCH=""
UNPACK_FUNCTION=""

# Do a case-insensitive match, because under Microsoft Windows we could see
# the known extension ins uppercase.
ARCHIVE_FILENAME_LOWER_CASE="${ARCHIVE_FILENAME,,}"

# There may be several matches, like ".gz and ".tar.gz". In that case,
# take the longest.

for KEY in "${!ALL_EXTENSIONS[@]}"
do

  KEY_IN_LOWER_CASE="${KEY,,}"

  if str_ends_with "$ARCHIVE_FILENAME_LOWER_CASE" "$KEY_IN_LOWER_CASE"; then

    if (( ${#KEY} > ${#LONGEST_EXTENSION_MATCH} )); then

      UNPACK_FUNCTION="${ALL_EXTENSIONS[$KEY]}"
      LONGEST_EXTENSION_MATCH="$KEY"

      if false; then
        echo "Unpack function found for '$LONGEST_EXTENSION_MATCH': $UNPACK_FUNCTION"
      fi

    fi

  fi
done

if [ -z "$UNPACK_FUNCTION" ]; then
  abort "Unknown archive type for filename \"$ARCHIVE_FILENAME\"."
fi

declare -r ARCHIVE_NAME_ONLY="${ARCHIVE_FILENAME##*/}"

declare -r -i EXT_LEN="${#LONGEST_EXTENSION_MATCH}"
declare -r ARCHIVE_NAME_ONLY_WITHOUT_EXT="${ARCHIVE_NAME_ONLY::-$EXT_LEN}"

TMP_DIRNAME="$(mktemp --directory --dry-run -- "$OUTPUT_DIRNAME/$ARCHIVE_NAME_ONLY_WITHOUT_EXT-unpacked-XXXXX")"

# Using mktemp's --dry-run is considered unsafe, but this is OK for this script.
# The trouble is, mktemp would create the subdirectory with very restrictive permissions.
# If we create it ourselves, the new subdirectory gets the default permissions,
# and that is what we want.
# We could let mktemp create the subdirectory and then use "chmod --reference=xxx" to copy
# the permissions from something else, but is is not clear what we could take as reference.
mkdir -- "$TMP_DIRNAME"

echo "Unpacking $ARCHIVE_FILENAME ..."

pushd "$TMP_DIRNAME" >/dev/null

set +o errexit

# Start a subshell for error-handling purposes: the routine called should fail straight away if
# any of the commands inside it fails, but we need to capture the error and carry on at the top-level.
(
  set -o errexit
  set -o nounset
  set -o pipefail

  "$UNPACK_FUNCTION"
)

declare -r -i UNPACK_EXIT_CODE="$?"

set -o errexit

popd >/dev/null

echo

if false; then
  echo "Analysing unpacked files..."
fi

shopt -s nullglob
shopt -s dotglob  # Include hidden files.

declare -a FILES_IN_TMP_DIR=( "$TMP_DIRNAME"/* )

if false; then

  for FILENAME in "${FILES_IN_TMP_DIR[@]}"
  do
    echo "Filename: $FILENAME"
  done

fi

declare -r -i UNPACKED_FILE_COUNT="${#FILES_IN_TMP_DIR[@]}"

declare -r TMP_DIRNAME_JUST_NAME="${TMP_DIRNAME##*/}"

if (( UNPACK_EXIT_CODE != 0 )); then

  if (( UNPACKED_FILE_COUNT == 0 )); then

    # We need to print some error message at all, just in case.
    # For example, UnZip 6.00 under Linux does not print the following error message
    # if we are using flag -q (quiet). We are using -q because otherwise the output is too verbose:
    #   Archive:  test.zip
    #      skipping: test.txt                need PK compat. v5.1 (can do v4.6)
    # With the -q flag, nothing is output at all, and the exit code is then 81.
    echo "Unpacking failed."

    rmdir -- "$TMP_DIRNAME"
  else
    echo "Unpacking failed. Some unpacked files have been left in subdirectory:"
    echo "  $TMP_DIRNAME_JUST_NAME/"
  fi

  exit "$UNPACK_EXIT_CODE"

fi


if (( UNPACKED_FILE_COUNT == 0 )); then
  # While theoretically possible, this should never happen in real life.

  rmdir -- "$TMP_DIRNAME"

  abort "The archive has no files inside."
fi

if (( UNPACKED_FILE_COUNT == 1 )); then

  declare -r THE_ONLY_FILENAME="${FILES_IN_TMP_DIR[0]}"

  if [ -d "$THE_ONLY_FILENAME" ]; then

    # If there is one single directory, keep its name.
    JUST_NAME="${THE_ONLY_FILENAME##*/}"

    if [ -e "$OUTPUT_DIRNAME/$JUST_NAME" ]; then
      echo "Archive unpacked into subdirectory:"
      echo "  $TMP_DIRNAME_JUST_NAME/"
      echo "because file or subdirectory \"$JUST_NAME\" already existed."
    else
      mv -- "$THE_ONLY_FILENAME"  "$OUTPUT_DIRNAME/"
      rmdir -- "$TMP_DIRNAME"
      echo "Archive unpacked into subdirectory:"
      echo "  $JUST_NAME/"
    fi

    exit $EXIT_CODE_SUCCESS
  fi

  if [ -f "$THE_ONLY_FILENAME" ]; then

    JUST_NAME="${THE_ONLY_FILENAME##*/}"

    if [ -e "$OUTPUT_DIRNAME/$JUST_NAME" ]; then
      echo "Archive unpacked into subdirectory:"
      echo "  $TMP_DIRNAME_JUST_NAME/"
      echo "because file or subdirectory \"$JUST_NAME\" already existed."
    else
      mv -- "$THE_ONLY_FILENAME"  "$OUTPUT_DIRNAME/"
      rmdir -- "$TMP_DIRNAME"
      echo "There was only one file to unpack. The filename is:"
      echo "  $JUST_NAME"
    fi

    exit $EXIT_CODE_SUCCESS
  fi

fi


declare -r DEST_DIR="$OUTPUT_DIRNAME/$ARCHIVE_NAME_ONLY_WITHOUT_EXT"

if [ -e "$DEST_DIR" ]; then
  echo "Archive unpacked into subdirectory:"
  echo "  $TMP_DIRNAME_JUST_NAME/"
  echo "because file or subdirectory \"$ARCHIVE_NAME_ONLY_WITHOUT_EXT\" already existed."
else
  mv -- "$TMP_DIRNAME" "$DEST_DIR"
  echo "Archive unpacked into subdirectory:"
  echo "  $ARCHIVE_NAME_ONLY_WITHOUT_EXT/"
fi
