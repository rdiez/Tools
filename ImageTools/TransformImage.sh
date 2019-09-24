#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

declare -r VERSION_NUMBER="1.02"
declare -r SCRIPT_NAME="TransformImage.sh"

declare -r EXIT_CODE_SUCCESS=0
declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}


verify_tool_is_installed ()
{
  local TOOL_NAME="$1"
  local DEBIAN_PACKAGE_NAME="$2"

  command -v "$TOOL_NAME" >/dev/null 2>&1  ||  abort "Tool '$TOOL_NAME' is not installed. You may have to install it with your Operating System's package manager. For example, under Ubuntu/Debian the corresponding package is called \"$DEBIAN_PACKAGE_NAME\"."
}


check_is_positive_integer ()
{
  local STR="$1"
  local ERR_MSG_PREFIX="$2"

  local IS_NUMBER_REGEX='^[0-9]+$'

  if ! [[ $STR =~ $IS_NUMBER_REGEX ]] ; then
    abort "${ERR_MSG_PREFIX}String \"$STR\" is not a positive integer."
  fi
}


display_help ()
{
cat - <<EOF

$SCRIPT_NAME version $VERSION_NUMBER
Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

Overview:

This tool crops and/or resizes a JPEG image with ImageMagick or jpegtran.
It is just a wrapper for convenience.

The resulting image is optimised in order to save disk space. Any EXIF information is removed.

Syntax:
  $SCRIPT_NAME <options...> <--> image.jpg

The resulting filename is image${OUTPUT_FILENAME_SUFFIX}.jpg .

Options:
 --crop     Crops according to an expression like "10L,11R,12T,13B", where
            L, R, T and B mean respectively left, right, top and bottom.
            The integer values are the number of pixels to crop.
            Alternatively, the expression "10X,11Y,12W,13H" specifies
            the top left coordinates and the size (width, height) to extract.
 --xres     Scales the image to the target horizontal resolution.
            The aspect ratio is maintaned.
 --help     Displays this help text.
 --version  Displays the tool's version number (currently $VERSION_NUMBER) .
 --license  Prints license information.
 --         Terminate options processing. Useful to avoid confusion between options and filenames
            that begin with a hyphen ('-'). Recommended when calling this script from another script,
            where the filename comes from a variable or from user input.

Usage example:
  ./$SCRIPT_NAME  --crop "500L,500R,500T,500B"  --xres 640  --  image.jpg

If you only specify the '--crop' operation, it will be performed in a lossless fashion,
so the cropping coordinates will no be entirely accurate. Search for "iMCU boundary"
in the jpegtran documentation for details.

Exit status: 0 means success. Any other value means error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

EOF
}


display_license()
{
cat - <<EOF

Copyright (c) 2019 R. Diez

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
    crop)
        if [[ $OPTARG = "" ]]; then
          abort "The '--crop' option has an empty value.";
        fi
        CROP_OPTION="$OPTARG"
        ;;
    xres)
        if [[ $OPTARG = "" ]]; then
          abort "The '--xres' option has an empty value.";
        fi
        XRES_OPTION="$OPTARG"
        ;;

    *)  # We should actually never land here, because parse_command_line_arguments() already checks if an option is known.
        abort "Unknown command-line option \"--${OPTION_NAME}\".";;
  esac
}


declare -r CONVERT_TOOL="convert"
declare -r IDENTIFY_TOOL="identify"
declare -r JPEGTRAN_TOOL="jpegtran"

declare -r ASCII_NUMBERS="0123456789"

# Example of text to parse: 123 456
declare -r DIMENSIONS_REGEX="^([$ASCII_NUMBERS]+) ([$ASCII_NUMBERS]+)\$"

# Example of text to parse: 123L,234R,345T,456B
declare -r CROP_REGEX_1="^([$ASCII_NUMBERS]+)L,([$ASCII_NUMBERS]+)R,([$ASCII_NUMBERS]+)T,([$ASCII_NUMBERS]+)B\$"
declare -r CROP_REGEX_2="^([$ASCII_NUMBERS]+)X,([$ASCII_NUMBERS]+)Y,([$ASCII_NUMBERS]+)W,([$ASCII_NUMBERS]+)H\$"


get_image_dimensions ()
{
  local -r FILENAME="$1"

  verify_tool_is_installed "$IDENTIFY_TOOL" "imagemagick"

  local CMD
  printf -v CMD \
         "%q -format %q -- %q" \
         "$IDENTIFY_TOOL" \
         "%w %h" \
         "$FILENAME"

  local DIMENSIONS
  DIMENSIONS="$(eval "$CMD")"

  if ! [[ $DIMENSIONS =~ $DIMENSIONS_REGEX ]] ; then
    abort "Cannot parse dimension expression: $DIMENSIONS"
  fi

  IMAGE_WIDTH="${BASH_REMATCH[1]}"
  IMAGE_HEIGHT="${BASH_REMATCH[2]}"

  if false; then
    echo "Image resolution: $IMAGE_WIDTH x $IMAGE_HEIGHT"
  fi
}


declare -r OUTPUT_FILENAME_SUFFIX="-transformed"

break_up_filename ()
{
  local -r FILENAME="$1"

  local -r BASENAME="${FILENAME##*/}"
  FILE_EXTENSION="${BASENAME##*.}"
  FILENAME_ONLY="${BASENAME%.*}"

  local FILENAME_ABS
  FILENAME_ABS="$(readlink --canonicalize --verbose -- "$FILENAME")"

  BASEDIR="${FILENAME_ABS%/*}"
  # We do not need to add a special case for the root directory, because
  # we will be appending a '/' first thing later on.
  #   if [[ $BASEDIR = "" ]]; then
  #     BASEDIR="/"
  #   fi

  # Variables BASEDIR, FILENAME_ONLY and FILE_EXTENSION are also 'exported' (not local)
  # in case the caller wants to build temporary filenames too,
  # in a similar way like we are building DEST_FILENAME_FINAL here.
  DEST_FILENAME_FINAL="$BASEDIR/${FILENAME_ONLY}${OUTPUT_FILENAME_SUFFIX}.$FILE_EXTENSION"
}


generate_extract_expression ()
{
  local -r CROP_EXPRESSION="$1"
  local -r IMAGE_WIDTH="$2"
  local -r IMAGE_HEIGHT="$3"

  if [[ $CROP_EXPRESSION =~ $CROP_REGEX_1 ]] ; then

    local -r CROP_LEFT="${BASH_REMATCH[1]}"
    local -r CROP_RIGHT="${BASH_REMATCH[2]}"
    local -r CROP_TOP="${BASH_REMATCH[3]}"
    local -r CROP_BOTTOM="${BASH_REMATCH[4]}"

    if false; then
      echo "CROP expression: $CROP_EXPRESSION"
      echo "CROP regex:      $CROP_REGEX_1"
      echo "CROP_LEFT  : $CROP_LEFT"
      echo "CROP_RIGHT : $CROP_RIGHT"
      echo "CROP_TOP   : $CROP_TOP"
      echo "CROP_BOTTOM: $CROP_BOTTOM"
    fi

    local -r -i EXTRACT_WIDTH="$(( IMAGE_WIDTH - CROP_LEFT - CROP_RIGHT ))"
    local -r -i EXTRACT_HEIGHT="$(( IMAGE_HEIGHT - CROP_TOP - CROP_BOTTOM ))"
    local -r -i EXTRACT_OFFSET_X="$CROP_LEFT"
    local -r -i EXTRACT_OFFSET_Y="$CROP_TOP"

    EXTRACT_EXPRESSION="${EXTRACT_WIDTH}x${EXTRACT_HEIGHT}+${EXTRACT_OFFSET_X}+${EXTRACT_OFFSET_Y}"

    return

  fi

  if [[ $CROP_EXPRESSION =~ $CROP_REGEX_2 ]] ; then

    EXTRACT_EXPRESSION="${BASH_REMATCH[3]}x${BASH_REMATCH[4]}+${BASH_REMATCH[1]}+${BASH_REMATCH[2]}"

    return

  fi

  abort "Cannot parse cropping expression: $CROP_EXPRESSION"

}


process_image_with_imagemagick ()
{
  local -r FILENAME="$1"
  local -r CROP_EXPRESSION="$2"
  local -r OUTPUT_XRES="$3"

  local FILE_EXTENSION
  local FILENAME_ONLY
  local BASEDIR
  local DEST_FILENAME_FINAL
  break_up_filename "$FILENAME"


  if [[ $CROP_EXPRESSION ]]; then

    # Hopefully, we are not doing just cropping, but scaling as well.
    # Otherwise, the caller should have called process_image_with_jpegtran() instead.

    local IMAGE_WIDTH
    local IMAGE_HEIGHT
    get_image_dimensions "$FILENAME"

    local EXTRACT_EXPRESSION
    generate_extract_expression "$CROP_EXPRESSION" "$IMAGE_WIDTH" "$IMAGE_HEIGHT"

    local -r EXTRACT_ARG="-extract $EXTRACT_EXPRESSION"

  else
    local -r EXTRACT_ARG=""
  fi


  if [[ $OUTPUT_XRES ]]; then
    local -r GEOMETRY_ARG="-geometry ${OUTPUT_XRES}x"
  else
    local -r GEOMETRY_ARG=""

    # The current caller will not call this routine if there is no scaling to do.
    abort "Internal error."
  fi


  verify_tool_is_installed "$CONVERT_TOOL"  "imagemagick"

  # With options "-strip  -interlace Plane", ImageMagick generates progressive, optimised JPEGs of similar size as "jpegtran -optimize -progressive".

  local CMD
  printf -v CMD \
         "%q  -strip  -interlace Plane  %s  %s  -- %q  %q" \
         "$CONVERT_TOOL" \
         "$EXTRACT_ARG" \
         "$GEOMETRY_ARG" \
         "$FILENAME" \
         "$DEST_FILENAME_FINAL"

  echo "$CMD"
  eval "$CMD"
}


process_image_for_lossless_cropping ()
{
  local -r FILENAME="$1"
  local -r CROP_EXPRESSION="$2"

  local FILE_EXTENSION
  local FILENAME_ONLY
  local BASEDIR
  local DEST_FILENAME_FINAL
  break_up_filename "$FILENAME"

  # We are determining the file content type based on the filename extension.
  # There are probably better ways to do this.
  FILE_EXTENSION_UPPERCASE=${FILE_EXTENSION^^}

  if [[ $FILE_EXTENSION_UPPERCASE != JPG && $FILE_EXTENSION_UPPERCASE != JPEG ]]; then
    abort "Lossless cropping is only supported on JPEG files at the moment (with file extension .jpg or .jpeg)."
  fi


  local IMAGE_WIDTH
  local IMAGE_HEIGHT
  get_image_dimensions "$FILENAME"

  local EXTRACT_EXPRESSION
  generate_extract_expression "$CROP_EXPRESSION" "$IMAGE_WIDTH" "$IMAGE_HEIGHT"

  verify_tool_is_installed "$JPEGTRAN_TOOL" "libjpeg-turbo-progs"

  # Unfortunately, tool 'jpegtran' does not seem able to use '--' as an option terminator.

  local CMD
  printf -v CMD \
         "%q  -optimize -progressive -perfect -crop %q  %q  >%q" \
         "$JPEGTRAN_TOOL" \
         "$EXTRACT_EXPRESSION" \
         "$FILENAME" \
         "$DEST_FILENAME_FINAL"

  echo "$CMD"
  eval "$CMD"
}


# --------------------------------------------------

USER_SHORT_OPTIONS_SPEC=""

# Use an associative array to declare how many arguments every long option expects.
# All known options must be listed, even those with 0 arguments.
declare -A USER_LONG_OPTIONS_SPEC
USER_LONG_OPTIONS_SPEC+=( [help]=0 )
USER_LONG_OPTIONS_SPEC+=( [version]=0 )
USER_LONG_OPTIONS_SPEC+=( [license]=0 )
USER_LONG_OPTIONS_SPEC+=( [crop]=1 )
USER_LONG_OPTIONS_SPEC+=( [xres]=1 )

CROP_OPTION=""
XRES_OPTION=""

parse_command_line_arguments "$@"

if (( ${#ARGS[@]} != 1 )); then
  abort "Invalid command-line arguments. Run this tool with the --help option for usage information."
fi

declare -r IMAGE_FILENAME="${ARGS[0]}"

if [[ ! $CROP_OPTION && ! $XRES_OPTION ]]; then
  abort "No operation specified."
fi

if [[ $XRES_OPTION ]]; then

  check_is_positive_integer "$XRES_OPTION" "Error in '--xres' option: "

  process_image_with_imagemagick "$IMAGE_FILENAME" "$CROP_OPTION" "$XRES_OPTION"

else

  process_image_for_lossless_cropping "$IMAGE_FILENAME" "$CROP_OPTION"

fi
