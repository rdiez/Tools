#!/bin/bash

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

declare -r CERTIFICATES_DIRNAME="$HOME/somewhere/openvpn-certificates"


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

printf -v CMD  "./easyrsa build-client-full %q nopass"  "$CLIENT_CERT_FILENAME"

echo "$CMD"
eval "$CMD"

declare -r CA_KEY_FILENAME="pki/ca.crt"
declare -r TA_KEY_FILENAME="ta.key"
declare -r CLIENT_CERT_FILENAME_CRT="pki/issued/$CLIENT_CERT_FILENAME.crt"
declare -r CLIENT_CERT_FILENAME_KEY="pki/private/$CLIENT_CERT_FILENAME.key"
declare -r DEST_CONFIG_DIR="generated-client-config-files"
declare -r DEST_FILENAME="$DEST_CONFIG_DIR/$CLIENT_CONFIG_FILENAME"

mkdir --parents -- "$DEST_CONFIG_DIR"


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
