#!/bin/sh

# This small script helps you pipe the output of a shell console command to the X clipboard.
#
# Usage: echo "whatever" | clipboard.sh
#        Then paste the copied text from the X clipboard into any application.

# The following xclip command does not work well with emacs, I don't know why,
# but I suspect it's because xclip remains as a background process
# detached from the console.
#   exec xclip -i -selection clipboard

exec xsel --input --clipboard
