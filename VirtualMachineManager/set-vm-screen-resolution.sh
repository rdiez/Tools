#!/bin/bash
#
# This script is a workaround for the virtual graphics card not automatically
# resizing to the host window size. This is a known problem with some desktop
# environments, see the following bug report:
#   https://bugzilla.redhat.com/show_bug.cgi?id=1290586
#
# Usage example: set-vm-screen-resolution.sh 1024 768
#
# You would normally use this command instead:
#  xrandr --output Virtual-0 --auto
# But, for some reason, "--auto" does not work properly for me.
# The resulting size tends to be too high.
#
# The most convenient way to use this script is to create a desktop icon
# to run it for your chosen resolution.
#
# This script only works once for a given resolution, see below for the reason why.
# This is enough for my purposes, but you may find it annoying.
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

if [ $# -ne 2 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi


declare -r HRES="$1"
declare -r VRES="$2"
declare -r SCREEN_NAME="Virtual-0"
declare -r MODE_NAME="MyModeForVM-${HRES}x${VRES}"

# We could calculate the other video mode parameters with tool 'gtf',
# but it is not worth it, because I think that those parameters are
# actually ignored in a virtual graphics card.
declare -r HRES_IGNPARAM="$HRES"
declare -r VRES_IGNPARAM="$VRES"

# Adding a mode will fail with a non-obvious error message if the
# mode name is already in use. Or maybe because the mode is being used.
# We could add logic to detect whether the mode already exists and/or
# is currently in use by parsing the output from "xrandr -q",
# but that is rather complicated.
# Therefore, this script will work only once.

printf -v CMD "xrandr --newmode %q  60  %q %q %q %q  %q %q %q %q  -hsync +vsync" \
       "$MODE_NAME" \
       "$HRES" "$HRES_IGNPARAM" "$HRES_IGNPARAM" "$HRES_IGNPARAM" \
       "$VRES" "$VRES_IGNPARAM" "$VRES_IGNPARAM" "$VRES_IGNPARAM"

echo "$CMD"
eval "$CMD"

printf -v CMD "xrandr --addmode %q  %q" \
       "$SCREEN_NAME"  "$MODE_NAME"

echo "$CMD"
eval "$CMD"

# With Ubuntu MATE 18.04.2 I have noticed that the "xrandr --output" command
# often fails. I guess that the new mode created and added above is not
# actually available yet. Adding a short pause seems to help.
sleep 0.5

printf -v CMD "xrandr --output %q  --mode %q" \
       "$SCREEN_NAME"   "$MODE_NAME"

echo "$CMD"
eval "$CMD"
