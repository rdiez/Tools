#!/bin/bash

# This script is an example wrapper for mount-sshfs.sh .
# See mount-sshfs.sh for more information.
#
# If mount-sshfs.sh is not on the PATH, specify its full path below.

mount-sshfs.sh  "MyFriendlySshHostName:/home/some/path"  "$HOME/MountPoints/some/path"  "$@"
