#!/bin/bash

# This script is an example wrapper for mount-gocryptfs.sh .
# See mount-gocryptfs.sh for more information.
#
# If mount-gocryptfs.sh is not on the PATH, specify its full path below.

mount-gocryptfs.sh  "/media/$USER/YourVolumeId/YourEncryptedDir" \
                    "$HOME/YourPasswordFile" \
                    "$HOME/AllYourMountDirectories/YourMountDirectory" \
                    "$@"
