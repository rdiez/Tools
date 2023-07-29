#!/bin/bash

# I usually write documentation in POD (Plain Old Documentation) format,
# which is a markup language. You can embeded POD in Perl scripts (.pl files)
# or have separate .pod files.
#
# This script checks that the POD syntax in the given file is OK, and then
# converts the documentation to HTML (in a fixed temporary file) and opens it
# with the standard Web browser. Such automated steps are convenient when
# writing or reading documentation.
#
# You need to install Perl on your system before running this script.
# It uses Perl module Pod::Simple::HTML, which is part of the Perl core modules,
# but still does not get installed together with Perl by default on many distributions.
# On Cygwin, the package is called 'perl-Pod-Simple', and on Ubuntu/Debian 'libpod-simple-perl'.
#
# This should have been a Perl script from the start.
#
# Copyright (c) 2016 R. Diez - Licensed under the GNU AGPLv3

set -o errexit
set -o nounset
set -o pipefail

abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}

is_var_set ()
{
  if [ "${!1-first}" == "${!1-second}" ]; then return 0; else return 1; fi
}

# ---------- Entry point ----------

if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. Please specify a single filename with POD contents."
fi

POD_FILENAME="$1"

# podchecker yields a non-zero exit code, which stops this script, if something is
# not quite right in the POD contents.
# Specifying option "-warnings" twice increases the warning level to 2 (the maximum at the moment).
podchecker -warnings -warnings -- "$POD_FILENAME"

# The following rules about finding the temporary directory are the same as mktemp's --tmpdir option.
if is_var_set TMPDIR; then
  PATH_TO_TEMP_DIR="$TMPDIR"
else
  PATH_TO_TEMP_DIR="/tmp"
fi

HTML_FILENAME="$PATH_TO_TEMP_DIR/view-pod-as-html.html"
# CONSOLE_OUTPUT_FILENAME="$PATH_TO_TEMP_DIR/view-pod-as-html.txt"

if false; then

  # I had trouble with pod2html in Perl v5.10.1.
  # But now with Perl v5.22.1, it seems OK.

  PERL_CMD="\$p = Pod::Simple::HTML->new; "
  PERL_CMD+="\$p->index( 1 ); "
  PERL_CMD+="\$p->output_fh( *STDOUT{IO} ); "
  PERL_CMD+="\$p->force_title( \"<view-pod-as-html>\" ); "

  # This is no proper way to escape a filename in Perl, but it should work
  # with most filenames.
  PERL_CMD+="\$p->parse_file( \"$POD_FILENAME\" ); "

  perl -MPod::Simple::HTML -e "$PERL_CMD" >"$HTML_FILENAME"

else

  pod2html "$POD_FILENAME" >"$HTML_FILENAME"

fi

echo "Opening generated file $HTML_FILENAME ..."

if [[ $OSTYPE = "cygwin" ]]; then
  cygstart "$HTML_FILENAME"
else
  # Leaving a program like Firefox running in the background is tricky.
  # The parent process may close stdin, stdout and stderr, making the
  # background child process fail when it tries to read from or write to them.
  # Or the parent terminal may send SIGHUP when it is closing,
  # killing all children.
  # The safest way is to use 'nohup'. But we need to keep the children's
  # output in some file. Otherwise, it will be very hard to troubleshoot any
  # eventual problem. The downside is, the file will accumulate everything
  # that Firefox writes to the console handle.
  #
  # echo "The console output for the child processes has been redirected to:"
  # echo "  $CONSOLE_OUTPUT_FILENAME"
  # nohup xdg-open "$HTML_FILENAME" >"$CONSOLE_OUTPUT_FILENAME"

  # The code above did not work for me on all systems when calling this script
  # from Emacs. I am avoiding xdg-open now, as it seems to work better.
  # trap "" HUP
  # firefox "$HTML_FILENAME" &

  # I am reverting to xdg-open, because I now have firefox-esr, and that
  # can change again in the future. I am now trying with a simple delay afterwards.
  xdg-open "$HTML_FILENAME"
  sleep 1
fi
