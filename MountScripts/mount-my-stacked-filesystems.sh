#!/bin/bash

# This script is an example wrapper for mount-stacked.sh .
# See mount-stacked.sh for more information.
#
# If mount-stacked.sh is not on the PATH, specify its full path below.

mount-stacked.sh  "$HOME/mount-my-sshfs-server.sh" \
                  "$HOME/mount-my-gocryptfs-vault.sh" \
                  "$@"
