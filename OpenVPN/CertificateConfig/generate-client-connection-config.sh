#!/bin/bash

# Usage example:
#
#   ./generate-client-connection-config.sh \
#       openvpn-client.conf.template       \
#       certificates/keys/ca.crt           \
#       certificates/keys/client1.crt      \
#       certificates/keys/client1.key      \
#       certificates/keys/ta.key           \
#       openvpn-client-config.ovpn
#
#
# Copyright (c) 2019-2023 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r SCRIPT_NAME="${BASH_SOURCE[0]##*/}"  # This script's filename only, without any path components.

declare -r -i EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$SCRIPT_NAME\": $*" >&2
  exit $EXIT_CODE_ERROR
}


extract_line_block_from_file ()
{
  local -r FILENAME="$1"
  local -r BEGIN_LINE="$2"
  local -r END_LINE="$3"

  local FILE_CONTENTS
  FILE_CONTENTS="$(<"$FILENAME")"

  # Split on newline characters.
  local FILE_LINES
  mapfile -t FILE_LINES <<< "$FILE_CONTENTS"

  local FILE_LINE_COUNT="${#FILE_LINES[@]}"

  local LINE_CONTENT
  local -i INDEX
  local -i BEGIN_LINE_INDEX=-1
  local -i END_LINE_INDEX=-1

  for (( INDEX=0; INDEX < FILE_LINE_COUNT; INDEX+=1 )); do

    LINE_CONTENT="${FILE_LINES[$INDEX]}"

    if [[ $LINE_CONTENT == "$BEGIN_LINE" ]]; then
      BEGIN_LINE_INDEX=$INDEX
      break;
    fi

  done

  if (( BEGIN_LINE_INDEX == -1 )); then
    abort "The beginning text line was not found."
  fi

  for (( ; INDEX < FILE_LINE_COUNT; INDEX+=1 )); do

    LINE_CONTENT="${FILE_LINES[$INDEX]}"

    if [[ $LINE_CONTENT == "$END_LINE" ]]; then
      END_LINE_INDEX=$INDEX
      break;
    fi

    if false; then
      echo "Line index $INDEX: $LINE_CONTENT"
    fi

  done

  if (( END_LINE_INDEX == -1 )); then
    abort "The ending text line was not found."
  fi

  local -i CAPTURE_LINE_COUNT=$(( END_LINE_INDEX - BEGIN_LINE_INDEX + 1 ))

  CAPTURED_BLOCK_AS_ARRAY=("${FILE_LINES[@]:$BEGIN_LINE_INDEX:$CAPTURE_LINE_COUNT}")

  printf -v CAPTURED_BLOCK_AS_MULTILINE_STRING  "\\n%s" "${CAPTURED_BLOCK_AS_ARRAY[@]}"
  CAPTURED_BLOCK_AS_MULTILINE_STRING=${CAPTURED_BLOCK_AS_MULTILINE_STRING:1}
}


# ------- Entry point -------

if (( $# != 6 )); then
  abort "Invalid number of command-line arguments. See this tool's source code for more information."
fi

declare -r TEMPLATE_FILENAME="$1"
declare -r ROOT_CERTIFICATE_FILENAME="$2"
declare -r CLIENT_CERTIFICATE_FILENAME="$3"
declare -r CLIENT_PRIVATE_KEY_FILENAME="$4"
declare -r TLS_AUTH_FILENAME="$5"
declare -r DESTINATION_FILENAME="$6"

STR="$(<"$TEMPLATE_FILENAME")"

extract_line_block_from_file  "$ROOT_CERTIFICATE_FILENAME" \
                              "-----BEGIN CERTIFICATE-----" \
                              "-----END CERTIFICATE-----"

declare -r ROOT_CERTIFICATE="$CAPTURED_BLOCK_AS_MULTILINE_STRING"

extract_line_block_from_file  "$CLIENT_CERTIFICATE_FILENAME" \
                              "-----BEGIN CERTIFICATE-----" \
                              "-----END CERTIFICATE-----"

declare -r CLIENT_CERTIFICATE="$CAPTURED_BLOCK_AS_MULTILINE_STRING"

extract_line_block_from_file  "$CLIENT_PRIVATE_KEY_FILENAME" \
                              "-----BEGIN PRIVATE KEY-----" \
                              "-----END PRIVATE KEY-----"

declare -r CLIENT_PRIVATE_KEY="$CAPTURED_BLOCK_AS_MULTILINE_STRING"

extract_line_block_from_file  "$TLS_AUTH_FILENAME" \
                              "-----BEGIN OpenVPN Static key V1-----" \
                              "-----END OpenVPN Static key V1-----"

declare -r TLS_AUTH_PRIVATE_KEY="$CAPTURED_BLOCK_AS_MULTILINE_STRING"

STR="${STR//<ROOT-CERTIFICATE-PLACEHOLDER>/$ROOT_CERTIFICATE}"
STR="${STR//<CLIENT-CERTIFICATE-PLACEHOLDER>/$CLIENT_CERTIFICATE}"
STR="${STR//<CLIENT-PRIVATE-KEY-PLACEHOLDER>/$CLIENT_PRIVATE_KEY}"
STR="${STR//<TLS_AUTH_PRIVATE_KEY>/$TLS_AUTH_PRIVATE_KEY}"

echo "$STR" >"$DESTINATION_FILENAME"

echo "Generated file: $DESTINATION_FILENAME"
