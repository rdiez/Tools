#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r VERSION_NUMBER="2.09"
declare -r SCRIPT_NAME="DownloadAndBuildAutotools.sh"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

declare -r GNU_FTP_SITE="ftpmirror.gnu.org"

# Otherwise, assume the files have already been downloaded. Useful only when developing this script.
declare -r DOWNLOAD_FILES=true

# Otherwise, carry on building where it failed last time. Useful only when developing this script.
declare -r START_CLEAN=true


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2011-2017 R. Diez - Licensed under the GNU AGPLv3

This script downloads, builds and installs any desired versions of the GNU autotools
(autoconf + automake + libtool), which are often needed to build many open-source projects
from their source code repositories.

You would normally use whatever autotools versions your Operating System provides,
but sometimes you need older or newer versions, or even different combinations
for testing purposes.

You should NEVER run this script as root nor attempt to upgrade your system's autotools versions.
In order to use the new autotools just built by this script, temporary prepend
the full path to the "bin" subdirectory underneath the installation directory
to your \$PATH variable, see option --prefix below.

Syntax:
  $SCRIPT_NAME  --autoconf-version=<nn>  --automake-version=<nn>  --libtool-version==<nn>  <other options...>

Options:
 --autoconf-version=<nn>  autoconf version to download and build
 --automake-version=<nn>  automake version to download and build
 --libtool-version=<nn>   libtool  version to download and build
 --prefix=/some/dir       directory where the binaries will be installed, see notes below
 --help     displays this help text
 --version  displays the tool's version number (currently $VERSION_NUMBER)
 --license  prints license information

Usage example:
  % cd some/dir  # The file cache and intermediate build results will land there.
  % ./$SCRIPT_NAME --autoconf-version=2.69 --automake-version=1.16.2 --libtool-version=2.4.6

About the installation directory:

If you specify with option '--prefix' the destination directory where the binaries will be installed,
and that directory already exists, its contents will be preserved. This way, you can install other tools
in the same destination directory, and they will all share the typical "bin" and "share" directory structure
underneath it that most autotools install scripts generate.

Make sure that you remove any old autotools from the destination directory before installing new versions.
Otherwise, you will end up with a mixture of old and new files, and something is going to break sooner or later.

If you do not specify the destination directory, a new one will be automatically created in the current directory.
Beware that this script will DELETE and recreate it every time it runs, in order to minimise chances
for mismatched file version. Therefore, it is best not to share it with other tools, in case you inadvertently
re-run this script and end up deleting all other tools as an unexpected side effect.

About the download cache and the intermediate build files:

This script uses 'curl' in order to download the files from $GNU_FTP_SITE ,
which should give you a fast mirror nearby.

The tarball for a given autotool version is downloaded only once to a local file cache,
so that it does not have to be downloaded again the next time around.
Do not run several instances of this script in parallel, because downloads
to the cache are not serialised or protected in any way against race conditions.

The file cache and the intermediate build files are placed in automatically-created
subdirectories of the current directory. The intermediate build files can be deleted
afterwards in order to reclaim disk space.

Interesting autotools versions:
- Ubuntu 16.04: autoconf 2.69, automake 1.15, libtool 2.4.6
- Latest as of march 2020: autoconf 2.69, automake 1.16.2, libtool 2.4.6

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2011-2017 R. Diez

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


delete_dir_if_exists ()
{
  # $1 = dir name

  if [ -d "$1" ]
  then
    # echo "Deleting directory \"$1\" ..."

    rm -rf -- "$1"

    # Sometimes under Windows/Cygwin, directories are not immediately deleted,
    # which may cause problems later on.
    if [ -d "$1" ]; then abort "Cannot delete directory \"$1\"."; fi
  fi
}


create_dir_if_not_exists ()
{
  # $1 = dir name

  if ! test -d "$1"
  then
    echo "Creating directory \"$1\" ..."
    mkdir --parents -- "$1"
  fi
}


download_tarball ()
{
  URL="$1"
  TEMP_FILENAME="$2"
  FINAL_FILENAME="$3"
  TAR_OPTION_TO_EXTRACT="$4"

  NAME_ONLY="${URL##*/}"

  if [ -f "$FINAL_FILENAME" ]; then
    echo "Skipping download of file \"$NAME_ONLY\", as it already exists in the cache directory."
    return 0
  fi

  echo "Downloading URL \"$URL\"..."

  curl --location --show-error --url "$URL" --output "$TEMP_FILENAME"

  # Test the archive before committing it to the cache with its final filename.
  # Some GNU mirrors use HTML redirects that curl cannot follow,
  # and once a corrupt archive lands in the destination directory,
  # it will stay corrupt until the user manually deletes it.

  echo "Testing the downloaded tarball \"$TEMP_FILENAME\"..."

  TMP_DIRNAME="$(mktemp --directory --tmpdir "$SCRIPT_NAME.XXXXXXXXXX")"

  pushd "$TMP_DIRNAME" >/dev/null

  set +o errexit
  tar --extract "$TAR_OPTION_TO_EXTRACT" --file "$TEMP_FILENAME"
  TAR_EXIT_CODE="$?"
  set -o errexit

  popd >/dev/null

  rm -rf -- "$TMP_DIRNAME"

  if [ $TAR_EXIT_CODE -ne 0 ]; then
    ERR_MSG="Downloaded archive file \"$URL\" failed the integrity test, see above for the detailed error message. "
    ERR_MSG="${ERR_MSG}The file may be corrupt, or curl may not have been able to follow a redirect properly. "
    ERR_MSG="${ERR_MSG}Try downloading the archive file from another location or mirror. "
    ERR_MSG="${ERR_MSG}You can inspect the corrupt file at \"$TEMP_FILENAME\"."
    abort "$ERR_MSG"
  fi

  mv "$TEMP_FILENAME" "$FINAL_FILENAME"
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
    autoconf-version)
      AUTOCONF_VERSION="$OPTARG"
        ;;
    automake-version)
      AUTOMAKE_VERSION="$OPTARG"
        ;;
    libtool-version)
      LIBTOOL_VERSION="$OPTARG"
        ;;
    prefix)
      PREFIX_DIR="$OPTARG"
      DELETE_PREFIX_DIR=false
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


# ------- Entry point -------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [autoconf-version]=1 )
USER_LONG_OPTIONS_SPEC+=( [automake-version]=1 )
USER_LONG_OPTIONS_SPEC+=( [libtool-version]=1 )
USER_LONG_OPTIONS_SPEC+=( [prefix]=1 )

AUTOCONF_VERSION=""
AUTOMAKE_VERSION=""
LIBTOOL_VERSION=""
PREFIX_DIR=""
DELETE_PREFIX_DIR=true

parse_command_line_arguments "$@"

if [ ${#ARGS[@]} -ne 0 ]; then
  abort "Too many command-line arguments. Run this tool with the --help option for usage information."
fi

if [[ $AUTOCONF_VERSION = "" ]]; then
  abort "You need to specify an autoconf version. Run this tool with the --help option for usage information."
fi

if [[ $AUTOMAKE_VERSION = "" ]]; then
  abort "You need to specify an automake version. Run this tool with the --help option for usage information."
fi

if [[ $LIBTOOL_VERSION = "" ]]; then
  abort "You need to specify a libtool version. Run this tool with the --help option for usage information."
fi

CURRENT_DIR_ABS="$(readlink --canonicalize --verbose -- "$PWD")"

DIRNAME_WITH_VERSIONS="autoconf-$AUTOCONF_VERSION-automake-$AUTOMAKE_VERSION-libtool-$LIBTOOL_VERSION"

if [[ $PREFIX_DIR = "" ]]; then
  PREFIX_DIR="$CURRENT_DIR_ABS/$DIRNAME_WITH_VERSIONS-bin"
fi


DOWNLOAD_CACHE_DIR="$CURRENT_DIR_ABS/AutotoolsDownloadCache"
TMP_DIR="$CURRENT_DIR_ABS/AutotoolsIntermediateBuildFiles/$DIRNAME_WITH_VERSIONS"

TARBALL_EXTENSION="tar.xz"
TAR_OPTION_TO_EXTRACT="--auto-compress"

DOWNLOAD_IN_PROGRESS_STR="download-in-progress"

AUTOCONF_TARBALL_TEMP_FILENAME="$DOWNLOAD_CACHE_DIR/autoconf-$AUTOCONF_VERSION-$DOWNLOAD_IN_PROGRESS_STR.$TARBALL_EXTENSION"
AUTOMAKE_TARBALL_TEMP_FILENAME="$DOWNLOAD_CACHE_DIR/automake-$AUTOMAKE_VERSION-$DOWNLOAD_IN_PROGRESS_STR.$TARBALL_EXTENSION"
LIBTOOL_TARBALL_TEMP_FILENAME="$DOWNLOAD_CACHE_DIR/libtool-$LIBTOOL_VERSION-$DOWNLOAD_IN_PROGRESS_STR.$TARBALL_EXTENSION"

AUTOCONF_TARBALL_FINAL_FILENAME_ONLY="autoconf-$AUTOCONF_VERSION.$TARBALL_EXTENSION"
AUTOMAKE_TARBALL_FINAL_FILENAME_ONLY="automake-$AUTOMAKE_VERSION.$TARBALL_EXTENSION"
LIBTOOL_TARBALL_FINAL_FILENAME_ONLY="libtool-$LIBTOOL_VERSION.$TARBALL_EXTENSION"

AUTOCONF_TARBALL_FINAL_FILENAME="$DOWNLOAD_CACHE_DIR/$AUTOCONF_TARBALL_FINAL_FILENAME_ONLY"
AUTOMAKE_TARBALL_FINAL_FILENAME="$DOWNLOAD_CACHE_DIR/$AUTOMAKE_TARBALL_FINAL_FILENAME_ONLY"
LIBTOOL_TARBALL_FINAL_FILENAME="$DOWNLOAD_CACHE_DIR/$LIBTOOL_TARBALL_FINAL_FILENAME_ONLY"

echo "The download cache directory is located at \"$DOWNLOAD_CACHE_DIR\""

if $DOWNLOAD_FILES
then
  # echo "Downloading the autotools..."

  create_dir_if_not_exists "$DOWNLOAD_CACHE_DIR"

  download_tarball "http://$GNU_FTP_SITE/autoconf/$AUTOCONF_TARBALL_FINAL_FILENAME_ONLY" "$AUTOCONF_TARBALL_TEMP_FILENAME" "$AUTOCONF_TARBALL_FINAL_FILENAME" "$TAR_OPTION_TO_EXTRACT"
  download_tarball "http://$GNU_FTP_SITE/automake/$AUTOMAKE_TARBALL_FINAL_FILENAME_ONLY" "$AUTOMAKE_TARBALL_TEMP_FILENAME" "$AUTOMAKE_TARBALL_FINAL_FILENAME" "$TAR_OPTION_TO_EXTRACT"
  download_tarball "http://$GNU_FTP_SITE/libtool/$LIBTOOL_TARBALL_FINAL_FILENAME_ONLY" "$LIBTOOL_TARBALL_TEMP_FILENAME" "$LIBTOOL_TARBALL_FINAL_FILENAME" "$TAR_OPTION_TO_EXTRACT"
fi

# This is probably not the best heuristic for make -j , but it's better than nothing.
MAKE_J_VAL="$(( $(getconf _NPROCESSORS_ONLN) + 1 ))"

AUTOCONF_SRC_SUBDIRNAME="autoconf-$AUTOCONF_VERSION"
AUTOMAKE_SRC_SUBDIRNAME="automake-$AUTOMAKE_VERSION"
LIBTOOL_SRC_SUBDIRNAME="libtool-$LIBTOOL_VERSION"

AUTOCONF_OBJ_DIR="$TMP_DIR/autoconf-obj"
AUTOMAKE_OBJ_DIR="$TMP_DIR/automake-obj"
LIBTOOL_OBJ_DIR="$TMP_DIR/libtool-obj"


if $START_CLEAN
then
  echo "Cleaning any previous build results..."
  if $DELETE_PREFIX_DIR; then
    delete_dir_if_exists "$PREFIX_DIR"
  fi
  delete_dir_if_exists "$TMP_DIR"
fi


create_dir_if_not_exists "$TMP_DIR"

pushd "$TMP_DIR" >/dev/null

echo "Uncompressing \"$AUTOCONF_TARBALL_FINAL_FILENAME\"..."
tar  --extract "$TAR_OPTION_TO_EXTRACT" --file "$AUTOCONF_TARBALL_FINAL_FILENAME"
if ! [ -d "$AUTOCONF_SRC_SUBDIRNAME" ]; then
  abort "Tarball \"$AUTOCONF_TARBALL_FINAL_FILENAME\" did not extract to the expected \"$AUTOCONF_SRC_SUBDIRNAME\" subdirectory when extracting to \"$TMP_DIR\"."
fi

echo "Uncompressing \"$AUTOMAKE_TARBALL_FINAL_FILENAME\"..."
tar  --extract "$TAR_OPTION_TO_EXTRACT" --file "$AUTOMAKE_TARBALL_FINAL_FILENAME"
if ! [ -d "$AUTOMAKE_SRC_SUBDIRNAME" ]; then
  abort "Tarball \"$AUTOMAKE_TARBALL_FINAL_FILENAME\" did not extract to the expected \"$AUTOMAKE_SRC_SUBDIRNAME\" subdirectory when extracting to \"$TMP_DIR\"."
fi

echo "Uncompressing \"$LIBTOOL_TARBALL_FINAL_FILENAME\"..."
tar  --extract "$TAR_OPTION_TO_EXTRACT" --file "$LIBTOOL_TARBALL_FINAL_FILENAME"
if ! [ -d "$LIBTOOL_SRC_SUBDIRNAME" ]; then
  abort "Tarball \"$LIBTOOL_TARBALL_FINAL_FILENAME\" did not extract to the expected \"$LIBTOOL_SRC_SUBDIRNAME\" subdirectory when extracting to \"$TMP_DIR\"."
fi

popd >/dev/null


echo "----------------------------------------------------------"
echo "Building libtool"
echo "----------------------------------------------------------"

create_dir_if_not_exists "$LIBTOOL_OBJ_DIR"

pushd "$LIBTOOL_OBJ_DIR" >/dev/null

# If configuration fails, it's often useful to have the help text in the log file.
echo "Here is the configure script help text, should you need it:"
"$TMP_DIR/$LIBTOOL_SRC_SUBDIRNAME/configure" --help

echo
echo "Configuring libtool..."
"$TMP_DIR/$LIBTOOL_SRC_SUBDIRNAME/configure" \
    --config-cache\
    --prefix="$PREFIX_DIR"

echo
echo "Building libtool..."
make -j $MAKE_J_VAL

echo
echo "Installing libtool to \"$PREFIX_DIR\"..."
make install

popd >/dev/null


echo "----------------------------------------------------------"
echo "Building autoconf"
echo "----------------------------------------------------------"

create_dir_if_not_exists "$AUTOCONF_OBJ_DIR"

pushd "$AUTOCONF_OBJ_DIR" >/dev/null

# If configuration fails, it's often useful to have the help text in the log file.
echo "Here is the configure script help text, should you need it:"
"$TMP_DIR/$AUTOCONF_SRC_SUBDIRNAME/configure" --help

echo
echo "Configuring autoconf..."
"$TMP_DIR/$AUTOCONF_SRC_SUBDIRNAME/configure" \
    --config-cache\
    --prefix="$PREFIX_DIR"

echo
echo "Building autoconf..."
make -j $MAKE_J_VAL

echo
echo "Installing autoconf to \"$PREFIX_DIR\"..."
make install

popd >/dev/null


# Automake needs the new autoconf version.
export PATH="${PREFIX_DIR}/bin:$PATH"


echo "----------------------------------------------------------"
echo "Building automake"
echo "----------------------------------------------------------"

create_dir_if_not_exists "$AUTOMAKE_OBJ_DIR"

pushd "$AUTOMAKE_OBJ_DIR" >/dev/null

# If configuration fails, it's often useful to have the help text in the log file.
echo "Here is the configure script help text, should you need it:"
"$TMP_DIR/$AUTOMAKE_SRC_SUBDIRNAME/configure" --help

echo
echo "Configuring automake..."
"$TMP_DIR/$AUTOMAKE_SRC_SUBDIRNAME/configure" \
    --config-cache\
    --prefix="$PREFIX_DIR"

echo
echo "Building automake..."
make -j $MAKE_J_VAL

echo
echo "Installing automake to \"$PREFIX_DIR\"..."
make install

popd >/dev/null

echo
echo "Finished building the autotools. You will probably want to prepend the bin directory to your PATH like this:"
echo "  export PATH=\"${PREFIX_DIR}/bin:\$PATH\""
echo
