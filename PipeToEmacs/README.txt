
pipe-to-emacs-server.sh version 2.03
Copyright (c) 2011-2021 R. Diez - Licensed under the GNU AGPLv3
Based on a similar utility by Phil Jackson (phil@shellarchive.co.uk)

This tool helps you pipe the output of a shell console command to a new Emacs window.

The Emacs instance receiving the text must already be running in the local PC, and must have started the Emacs server, as this script uses the 'emacsclient' tool. See Emacs' function 'server-start' for details. I tried to implement this script so that it would start Emacs automatically if not already there, but I could not find a clean solution. See this script's source code for more information. The reason why the Emacs server must be running locally is that the generated lisp code needs to open a local temporary file where the piped text is stored.

If you Emacs is not on the PATH, se environment variable EMACS_BASE_PATH.

If you are running on Cygwin and want to use the native Windows Emacs (the Win32 version instead of the Cygwin one), set environment variable PIPETOEMACS_WIN32_PATH to point to your Emacs binaries. For example:
  export PIPETOEMACS_WIN32_PATH="c:/emacs-24.3"

Usage examples:
  ls -la | pipe-to-emacs-server.sh
  my-program 2>&1 | pipe-to-emacs-server.sh  # Include output to stderr too.

You can also specify one of the following options:
 --help     displays this help text
 --version  displays the tool's version number (currently 2.03)
 --license  prints license information

Exit status: 0 means success, anything else is an error.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de
