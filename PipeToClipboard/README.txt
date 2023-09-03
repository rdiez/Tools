
---- pipe-to-clipboard.sh ----

This script helps you pipe the output of a shell command to the X clipboard.

It is just a wrapper around 'xsel', partly because I can never remember its command-line arguments.

If case of a single text line, the script automatically removes the end-of-line character.
Otherwise, pasting the text to a shell console becomes annoying.


---- path-to-clipboard.sh ----

Places the absolute path of the given filename in the X clipboard.
It does not resolve symbolic links, so it should be the same path you normally see in your shell.
