
CheckVersion.sh version 1.02
Copyright (c) 2014 R. Diez - Licensed under the GNU AGPLv3

Overview:

This scripts helps generate an error or warning message if a given version number
is different/less than/etc. compared to a reference version number.

Syntax:
  CheckVersion.sh [options...] [--] <version name> <detected version> <comparator> <reference version>

Possible comparators are: <, <=, >, >=, ==, != and their aliases lt, le, gt, ge, eq, ne.

Version numbers must be a sequence of integer numbers separated by periods, like "1.2.3".
Version components are compared numerically, so version "01.002.3.0.0" is equivalent to the example above,
and versions "1.5" and "1.2.3.4" are considered greater.

Options:
 --help     displays this help text
 --version  displays this tool's version number (currently 1.02)
 --license  prints license information
 --warning-stdout  prints a warning to stdout but still exit with status code 0 (success)
 --warning-stderr  prints a warning to stderr but still exit with status code 0 (success)
 --result-as-text  prints "true" or "false" depending on whether the condition succeeds or fails

Usage example:
  ./CheckVersion.sh "MyTool" "1.2.0" ">=" "1.2.3"  # This check fails, so it prints an error message.

Exit status:
Normally, 0 means success, and any other value means error,
but some of command-line switches above change this behaviour.

Capturing version numbers:
Some tools make it easy to capture their version numbers. For example, GCC has switch "-dumpversion",
which just prints its major version number without any decoration (like "4.8"). In the case of GCC,
that switch is actually poorly implemented, because it only gives you the major version number, so
you may want to use switch "--version" instead, which prints the complete version number. Unfortunately,
the version string is not alone anymore, you get a text line like "gcc (Ubuntu 4.8.2-19ubuntu1) 4.8.2"
followed by some software license text. Many tools have no way to print an isolated version number.
For example, OpenOCD prints a line (to stderr!) like "Open On-Chip Debugger 0.7.0 (2013-10-22-08:31)".

Therefore, you often have to resort to unreliable text parsing. It is important to remember that
the version message is normally not rigidly specified, so it could change in the future and break
your version check script, or worse, make it always succeed without warning.

If you are writing software, please include a way to cleanly retrieve an isolated version number,
so that it is easy to parse reliably.

This is an example in bash of how you could parse and check OpenOCD's version string:

  OPENOCD_VERSION_TEXT="$("openocd" --version 2>&1)"

  VERSION_REGEX="([[:digit:]]+.[[:digit:]]+.[[:digit:]]+)"

  if [[ $OPENOCD_VERSION_TEXT =~ $VERSION_REGEX ]]; then
    VERSION_NUMBER_FOUND="${BASH_REMATCH[1]}"
  else
    abort "Could not determine OpenOCD's version number."
  fi

  CheckVersion.sh "OpenOCD" "$VERSION_NUMBER_FOUND" ">=" "0.8.0"


Version history:
1.00, Sep 2014: First release.
1.02, Sep 2014: Fixed versions with leading '0' being interpreted as octal numbers. Added != operator.

Feedback: Please send feedback to rdiezmail-tools at yahoo.de

