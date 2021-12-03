#!/bin/bash

# Copyright (c) 2019-2021 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

# set -x  # Enable tracing of this script.

declare -r EXIT_CODE_ERROR=1

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit $EXIT_CODE_ERROR
}

declare -r CERTIFICATES_DIRNAME="$HOME/somewhere/openvpn-certificates"

declare -r EASY_RSA_VERSION=3

case "$EASY_RSA_VERSION" in
  2) ;;
  3) ;;
  *) abort "Invalid EASY_RSA_VERSION value \"$EASY_RSA_VERSION\"."
esac


# ------- Entry point -------

if (( $# != 1 )); then
  abort "Invalid number of command-line arguments. Please specify an ID for the client like '123'."
fi

declare -r CLIENT_NAME="$1"

THIS_SCRIPT_DIR="$PWD"

CERTIFICATES_DIRNAME_ABS="$(readlink --canonicalize-existing --verbose -- "$CERTIFICATES_DIRNAME")"

DATE_STR="$(date "+%F")"

declare -r CLIENT_CERT_FILENAME="openvpn-client-$CLIENT_NAME-$DATE_STR-cert"
declare -r CLIENT_CONFIG_FILENAME="openvpn-client-$CLIENT_NAME-$DATE_STR-config.ovpn"

echo "Changing to directory \"$CERTIFICATES_DIRNAME_ABS\"..."
pushd "$CERTIFICATES_DIRNAME_ABS" >/dev/null

if [[ $EASY_RSA_VERSION = "2" ]]; then
  CMD="source ./vars"
  echo "$CMD"
  eval "$CMD"
fi


# If you get the following error message:
#   failed to update database
#   TXT_DB error number 2
# it means that you are generating a certificate for a common name that has already had a (different) certificate issued.
# Even if you no longer have a copy of that certificate, OpenSSL still remembers that it issued one.
# To fix the problem, edit the "keys/index.txt" file and remove the line that belongs to the old certificate.
#
# That method works if you made a mistake when generating the certificate.
# Remember that whitelisting uses the common name at the moment, so a new certificate should never have
# the same common name as an old, cancelled one. That is part of the reason why certificate common names
# include the issue date.

if [[ $EASY_RSA_VERSION = "2" ]]; then
  printf -v CMD  "./build-key --batch %q"  "$CLIENT_CERT_FILENAME"
else
  printf -v CMD  "./easyrsa build-client-full %q nopass"  "$CLIENT_CERT_FILENAME"
fi

echo "$CMD"
eval "$CMD"

if [[ $EASY_RSA_VERSION = "2" ]]; then
  declare -r CA_KEY_FILENAME="keys/ca.crt"
  declare -r TA_KEY_FILENAME="keys/ta.key"
  declare -r CLIENT_CERT_FILENAME_CRT="keys/$CLIENT_CERT_FILENAME.crt"
  declare -r CLIENT_CERT_FILENAME_KEY="keys/$CLIENT_CERT_FILENAME.key"
  declare -r DEST_FILENAME="keys/$CLIENT_CONFIG_FILENAME"
  declare -r DEST_CONFIG_DIR="keys"
else
  declare -r CA_KEY_FILENAME="pki/ca.crt"
  declare -r TA_KEY_FILENAME="ta.key"
  declare -r CLIENT_CERT_FILENAME_CRT="pki/issued/$CLIENT_CERT_FILENAME.crt"
  declare -r CLIENT_CERT_FILENAME_KEY="pki/private/$CLIENT_CERT_FILENAME.key"
  declare -r DEST_CONFIG_DIR="generated-client-config-files"
  declare -r DEST_FILENAME="$DEST_CONFIG_DIR/$CLIENT_CONFIG_FILENAME"

  mkdir --parents -- "$DEST_CONFIG_DIR"
fi

printf -v CMD \
       "%q %q %q %q %q %q %q " \
       "$THIS_SCRIPT_DIR/generate-client-connection-config.sh" \
       "$THIS_SCRIPT_DIR/openvpn-client.conf.template" \
       "$CA_KEY_FILENAME"            \
       "$CLIENT_CERT_FILENAME_CRT"   \
       "$CLIENT_CERT_FILENAME_KEY"   \
       "$TA_KEY_FILENAME"            \
       "$DEST_FILENAME"

echo "$CMD"
eval "$CMD"

DEST_FILENAME_ABS="$(readlink --canonicalize-existing --verbose -- "$DEST_FILENAME")"

echo "OpenVPN client configuration file generated:"
echo "  $DEST_FILENAME_ABS"
echo
echo "Some Linux clients may need the individual files:"
echo "- $TA_KEY_FILENAME"
echo "- $CA_KEY_FILENAME"
echo "- $CLIENT_CERT_FILENAME_CRT"
echo "- $CLIENT_CERT_FILENAME_KEY"
echo
echo "You need to add the following line with the certificate's common name to file 'allowed-clients.txt' on the OpenVPN server:"
echo "  $CLIENT_CERT_FILENAME"

popd >/dev/null
