
This script helps you pipe the output of a shell command to the X clipboard.

It is just a wrapper around 'xsel', partly because I can never remember its command-line arguments.

If case of a single text line, the script automatically removes the end-of-line character.
Otherwise, pasting the text to a shell console becomes annoying.
