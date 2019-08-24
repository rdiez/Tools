#!/bin/bash

# WebPictureGenerator.sh version 1.00
#
# This is the script I use to generate pictures for a web site from high-resolution photographs.
#
# Copyright (c) 2019 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail


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


declare -r CONVERT_TOOL="convert"
declare -r IDENTIFY_TOOL="identify"
declare -r COMPOSITE_TOOL="composite"
declare -r EXIF_TOOL="exiftool"

declare -r ASCII_NUMBERS="0123456789"

# Example of text to parse: 123 456
declare -r DIMENSIONS_REGEX="^([$ASCII_NUMBERS]+) ([$ASCII_NUMBERS]+)\$"

# Example of text to parse: 123L,234R,345T,456B
declare -r CROP_REGEX="^([$ASCII_NUMBERS]+)L,([$ASCII_NUMBERS]+)R,([$ASCII_NUMBERS]+)T,([$ASCII_NUMBERS]+)B\$"


get_image_dimensions ()
{
  local -r FILENAME="$1"

  local CMD

  printf -v CMD \
         "%q -format %q %q" \
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


generate_watermark_bitmap ()
{
  local -r TEXT="$1"
  local -r FONT_POINTSIZE="$2"
  local -r FILENAME="$3"

  local -r BACKGROUND_COLOUR="none"  # 'none' means the background will be transparent.
  local -r FIRST_COLOUR="gray20"
  local -r SECOND_COLOUR="gray70"

  local CMD

  # Draw the text once on an image that is just big enough for that text.
  # Then add 2 pixels to the right and to the bottom of the picture,
  # and draw the text again with a different colour and with a 2x2 offset.

  printf -v CMD \
         "%q  -font %q  -pointsize %s  -background $BACKGROUND_COLOUR  -fill $FIRST_COLOUR  label:%q  -gravity southeast  -splice 2x2  -gravity northwest  -fill $SECOND_COLOUR -draw 'text 2,2 %s'  %q" \
         "$CONVERT_TOOL" \
         "$FONT_NAME" \
         "$FONT_POINTSIZE" \
         "$TEXT" \
         "$TEXT" \
         "$FILENAME"

  echo "$CMD"
  eval "$CMD"
}


process_image ()
{
  local -r FILENAME="$1"
  local -r CROP="$2"
  local -r OUTPUT_XRES="$3"
  local -r VISIBLE_WATERMARK_FONT_POINTSIZE="$4"
  local -r VISIBLE_WATERMARK_GRAVITY="$5"
  local -r COPYRIGHT_YEAR="$6"
  local -r TEMP_DIR="$7"
  local -r DEST_DIR="$8"

  echo "Processing $FILENAME ..."

  local -r BASENAME="${FILENAME##*/}"
  local -r FILE_EXTENSION="${BASENAME##*.}"
  local -r FILENAME_ONLY="${BASENAME%.*}"

  # The intermediate files are PNG. With JPEG we would lose quality an every step.
  local -r WATERMARK_FILENAME="$TEMP_DIR/${FILENAME_ONLY}-watermark.png"
  local -r DEST_FILENAME_1="$TEMP_DIR/${FILENAME_ONLY}-temp1.png"

  local -r DEST_FILENAME_FINAL="$DEST_DIR/${FILENAME_ONLY}-web.$FILE_EXTENSION"

  if false; then
    echo "FILE_EXTENSION     : $FILE_EXTENSION"
    echo "DEST_FILENAME_1    : $DEST_FILENAME_1"
    echo "DEST_FILENAME_FINAL: $DEST_FILENAME_FINAL"
  fi


  local IMAGE_WIDTH
  local IMAGE_HEIGHT

  get_image_dimensions "$FILENAME"

  generate_watermark_bitmap "$VISIBLE_WATERMARK_TEXT" "$VISIBLE_WATERMARK_FONT_POINTSIZE" "$WATERMARK_FILENAME"


  local CMD

  if ! [[ $CROP =~ $CROP_REGEX ]] ; then
    abort "Cannot parse cropping expression: $CROP"
  fi

  local -r CROP_LEFT="${BASH_REMATCH[1]}"
  local -r CROP_RIGHT="${BASH_REMATCH[2]}"
  local -r CROP_TOP="${BASH_REMATCH[3]}"
  local -r CROP_BOTTOM="${BASH_REMATCH[4]}"

  if false; then
    echo "CROP expression: $CROP"
    echo "CROP regex:      $CROP_REGEX"
    echo "CROP_LEFT  : $CROP_LEFT"
    echo "CROP_RIGHT : $CROP_RIGHT"
    echo "CROP_TOP   : $CROP_TOP"
    echo "CROP_BOTTOM: $CROP_BOTTOM"
  fi

  local -r -i EXTRACT_WIDTH="$(( IMAGE_WIDTH - CROP_LEFT - CROP_RIGHT ))"
  local -r -i EXTRACT_HEIGHT="$(( IMAGE_HEIGHT - CROP_TOP - CROP_BOTTOM ))"
  local -r -i EXTRACT_OFFSET_X="$CROP_LEFT"
  local -r -i EXTRACT_OFFSET_Y="$CROP_TOP"

  # For development purposes you can disable below the image resizing.
  if true; then
    local -r TARGET_SIZE="-geometry ${OUTPUT_XRES}x"
  else
    local -r TARGET_SIZE=""
  fi

  # Crop the image by extracting a portion to a temporary image file.
  # Then resize the image (normally to reduce its resolution).
  printf -v CMD \
         "%q  -extract ${EXTRACT_WIDTH}x${EXTRACT_HEIGHT}+${EXTRACT_OFFSET_X}+${EXTRACT_OFFSET_Y}  %s  %q  %q" \
         "$CONVERT_TOOL" \
         "$TARGET_SIZE" \
         "$FILENAME" \
         "$DEST_FILENAME_1"

  echo "$CMD"
  eval "$CMD"

  # Merge the watermark picture.
  printf -v CMD \
         "%q -dissolve 30%%  -gravity %q -geometry  +$(( VISIBLE_WATERMARK_FONT_POINTSIZE * 1 / 3 ))+0  %q  %q  %q" \
         "$COMPOSITE_TOOL" \
         "$VISIBLE_WATERMARK_GRAVITY" \
         "$WATERMARK_FILENAME" \
         "$DEST_FILENAME_1" \
         "$DEST_FILENAME_FINAL"

  echo "$CMD"
  eval "$CMD"

  # Add the copyright information to the EXIF data.
  local -r COPYRIGHT_STRING="(c) $COPYRIGHT_YEAR $COPYRIGHT_NAME, all rights reserved"

  printf -v CMD \
         "%q  -overwrite_original  -rights=%q  -CopyrightNotice=%q  -quiet  %q" \
         "$EXIF_TOOL" \
         "$COPYRIGHT_STRING" \
         "$COPYRIGHT_STRING" \
         "$DEST_FILENAME_FINAL"

  echo "$CMD"
  eval "$CMD"

  echo
}


process_all_images ()
{
  local -r FONT_NAME="DejaVu-Sans-Mono"
  local -r VISIBLE_WATERMARK_TEXT="rdiez"
  local -r COPYRIGHT_NAME="rdiez"

  local -r SRC_DIR1="$HOME/rdiez/temp/WebPictureGenerator/Pictures"
  local -r DEST_DIR1="$HOME/rdiez/temp/WebPictureGenerator/Pictures-Web"
  local -r TEMP_DIR1="$HOME/rdiez/temp/WebPictureGenerator/Pictures-Temp"

  mkdir --parents -- "$DEST_DIR1"
  mkdir --parents -- "$TEMP_DIR1"

  process_image "$SRC_DIR1/pic1.jpg"  "500L,500R,500T,500B"  640  20 south-west  2019  "$TEMP_DIR1" "$DEST_DIR1"
  process_image "$SRC_DIR1/pic2.jpg"  "500L,10R,20T,30B"     640  20 south-west  2019  "$TEMP_DIR1" "$DEST_DIR1"
  process_image "$SRC_DIR1/pic3.jpg"  "500L,10R,20T,300B"    640  20 south-east  2019  "$TEMP_DIR1" "$DEST_DIR1"
}


verify_tool_is_installed "$CONVERT_TOOL" "imagemagick"
verify_tool_is_installed "$EXIF_TOOL" "libimage-exiftool-perl"

process_all_images

echo "Done."
