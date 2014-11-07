#!/bin/bash

# This script downloads a set of Wiki pages in several formats from a MediaWiki server.
#
# Usage:
#
# First of all, you will have to modify function 'place_your_own_urls_here' below.
#
# This script takes the download destination directory as the one and only argument.
#
# For maximum comfort, see companion script BackupExampleWithRotateDir.sh , which
# uses RotateDir.pl in order to automatically rotate the backup directories.
#
# Motivation:
#
# During the past years, I have written quite a few Wiki pages on a public MediaWiki server,
# and I wanted to back up the whole set at once. After I amend a page or create a new one,
# I want to re-run the backup process without too much fuss. This way, if the Wiki server
# suddenly disappears, it should be easy to get my pages published again
# on the next server that comes along.
#
# Besides, having offline copies of your Wiki pages in several formats allows you to consult,
# search or print them without Internet access.
#
#
# Copyright (c) 2014 R. Diez
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 for more details.
#
# You should have received a copy of the GNU Affero General Public License version 3
# along with this program.  If not, see L<http://www.gnu.org/licenses/>.

set -o errexit
set -o nounset
set -o pipefail


place_your_own_urls_here ()
{
  COMMON_PREFIX="https://www.devtal.de/w/index.php?title=Benutzer:Rdiez"

  add_page_url "RootIndexPage" "$COMMON_PREFIX"


  # add_page() uses variable PREFIX.
  PREFIX="$COMMON_PREFIX/"

  add_page "BuildingEmacsFromSource"
  add_page "DonatingIdleComputerTime"
  add_page "BugfixesSatzungDevtal"
  add_page "AssertAgainstNullPointerArgumentInC"
  add_page "YouProbablyShouldWriteProperShutdownLogic"
  add_page "HowToWriteMaintainableInitialisationAndTerminationCode"
  add_page "8-bitAVRsAndSimilarMicrocontrollersAreNotOkAnymore"
  add_page "ErrorHandling"
  add_page "AvoidStdString"
  add_page "HardwareDesign"
  add_page "ArduinoDue"
  add_page "Adler-32_checksum_in_AVR_Assembler"
  add_page "OutlookAttachmentRemover"
  add_page "Linux_Ramblings"
  add_page "SerialPortTipsForLinux"
  add_page "Linux_zram"
  add_page "BrittleOperatingSystems"
  add_page "BuyingALightBulb"
  add_page "WieManMitgliedsbeitr%C3%A4geVonDerSteuerAbsetzt"
  add_page "Deine_Privatsph%C3%A4re_in_der_Praxis"
  add_page "Apple_Ger%C3%A4te_haben_in_dev_tal_nichts_zu_suchen"
  add_page "Tourismus_in_der_N%C3%A4he"
  add_page "LaptopKaufkriterien"
  add_page "NaviKaufkriterien"
  add_page "HandyKaufkriterien"
  add_page "FernseherKaufkriterien"
  add_page "Sachen_in_meiner_/dev/tal_Kiste_f%C3%BCr_alle"
}


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


add_page_url ()
{
  PAGE_ARRAY+=( "$1" "$2" )
}


declare -a PAGE_ARRAY=()

add_page ()
{
  add_page_url "$1" "$PREFIX$1"
}


download_url ()
{
  FILENAME="$1"
  URL="$2"

  CMD="$CURL_TOOL_NAME"
  CMD+=" \"$URL\""
  CMD+=" --progress-bar"  # We don't need a progress bar, but the only alternative is --silent,
                          # which also suppresses any eventual error messages.
  CMD+=" --insecure"  # Do not worry if the remote SSL site cannot be trusted because the corresponding CA certificates are not installed.
  CMD+=" --output \"$FILENAME\""

  echo "$CMD"
  eval "$CMD"
}


download_page ()
{
  PAGE_FILENAME="$1"
  PAGE_URL="$2"

  # Sanitize the filename.
  PAGE_FILENAME="${PAGE_FILENAME//[ \/()$+&\.\-\'\,]/_}"
  PAGE_FILENAME="$TARGET_DIR/$PAGE_FILENAME"

  # You can export the pages as MediaWiki XML or RDF, see pages "Special:Export" and "Special:ExportRDF".
  # However, I could not get those pages to work properly on my current server.

  download_url "$PAGE_FILENAME.wiki-view.html"    "${PAGE_URL}&action=view"
  download_url "$PAGE_FILENAME.content-only.html" "${PAGE_URL}&action=render"
  download_url "$PAGE_FILENAME.printable.html"    "${PAGE_URL}&printable=yes"
  download_url "$PAGE_FILENAME.wiki-markup.txt"   "${PAGE_URL}&action=raw"
}


if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi

TARGET_DIR="$1"

CURL_TOOL_NAME="curl"

if ! type "$CURL_TOOL_NAME" >/dev/null 2>&1 ;
then
  abort "Tool \"$CURL_TOOL_NAME\" is not installed on this system."
fi

place_your_own_urls_here

declare -i PAGE_ARRAY_ELEM_COUNT="${#PAGE_ARRAY[@]}"
declare -i PAGE_ELEM_COUNT=2
declare -i FILE_COUNT="$(( PAGE_ARRAY_ELEM_COUNT / PAGE_ELEM_COUNT ))"

for ((i=0; i<$PAGE_ARRAY_ELEM_COUNT; i+=$PAGE_ELEM_COUNT)); do

  PAGE_FILENAME="${PAGE_ARRAY[$i]}"
  PAGE_URL="${PAGE_ARRAY[$((i+1))]}"

  download_page "$PAGE_FILENAME" "$PAGE_URL"

done

echo "Success backing up $FILE_COUNT wiki pages."
