
call-emacs-function.sh version 1.01
Copyright (c) 2026 R. Diez - Licensed under the GNU AGPLv3

This tool helps you call an arbitrary Emacs Lisp function with arbitrary arguments from the shell.

The target Emacs instance must already be running, and must have started the Emacs server, as this script uses the 'emacsclient' tool. See Emacs' function 'server-start' for details. I tried to implement this script so that it would start Emacs automatically if not already there, but I could not find a clean solution. See this script's source code for more information.

Emacs version 30.1 or later is required, as this script uses 'server-eval-args-left'.

If your Emacs is not on the PATH, set environment variable EMACS_BASE_PATH. This script will then use ${EMACS_BASE_PATH}/bin/emacsclient.

Syntax:
  call-emacs-function.sh <options...> <--> lisp-function-name <funtion arguments...>

Usage example:
  call-emacs-function.sh -- message-box "Test args: %s %s" "arg1" "arg2"

You can specify the following options:
 --help     displays this help text
 --version  displays the tool's version number (currently 1.01)
 --license  prints license information
 --suppress-output  When successful, do not show the result of the Lisp function, which is often just nil.
 --show-cmd         Shows the 'emacsclient' command which this script builds and runs.

Exit status: 0 means success, anything else is an error.

CAVEAT: A function argument cannot be an empty string. This is a bug in Emacs 30.x.
        For more information see the following bug report:
        https://debbugs.gnu.org/cgi/bugreport.cgi?bug=80356

This script could be extended to optionally use 'emacs' instead of 'emacsclient'.
Then it would need to run "emacs --funcall" and use 'command-line-args-left'.

Feedback: Please send feedback to rdiez-tools at rd10.de


See also example script ediff.sh, which uses call-emacs-function.sh in order to run Ediff on a pair of files.
That script needs a routine like the following in your Emacs configuration:

  (defun my-ediff-files-from-outside (filename-a filename-b)
    "" ; No docstring yet.
    (ediff-files filename-a filename-b))

You could call ediff-files directly, but I needed to customize the code in my Emacs configuration.
